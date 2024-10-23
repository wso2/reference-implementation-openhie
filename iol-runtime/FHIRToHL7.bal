import ballerina/time;
import ballerinax/health.fhir.r4;
import ballerinax/health.fhir.r4.international401;

// // Main function to trigger conversion
// public function main() returns error? {
//     // Parse the FHIR patient resource
//     international401:Patient fhirPatient = check parser:parse(samplePatient).ensureType();

//     // Convert FHIR patient to HL7v2 message
//     string hl7msg = check mapFhirPatientToHL7(fhirPatient, "SendingApp", "SendingFac", "ReceivingApp", "ReceivingFac", "12345");

//     // Print HL7 message
//     io:println(hl7msg);
// }

// Function to map a FHIR Patient resource to HL7v2
public isolated function mapFhirPatientToHL7(
        international401:Patient fhirPatient,
        string sendingApp,
        string sendingFacility,
        string receivingApp,
        string receivingFacility,
        string messageControlId) returns string|error {

    // Extract fields from FHIR Patient resource
    string patientId = fhirPatient.id.toString();

    r4:HumanName[] name = check fhirPatient.name.ensureType();
    string familyName = check name[0].family.ensureType();
    string givenName = string:'join(" ", ...check name[0].given.ensureType());
    string gender = check getGenderHL7(fhirPatient.gender.toString());
    string birthDate = fhirPatient.birthDate.toString();

    // Address Data
    r4:Address[] address = check fhirPatient.address.ensureType();
    string addressLine = string:'join(" ", ...check address[0].line.ensureType());
    string city = check address[0].city.ensureType();
    string state = check address[0].state.ensureType();
    string postalCode = check address[0].postalCode.ensureType();

    // Telecom (phone) data
    r4:ContactPoint[] phone_ = check fhirPatient.telecom.ensureType();
    string phone = check phone_[0].value.ensureType();

    // Message date-time
    string messageDateTime = getCurrentTimestamp();

    // For patient admit events
    string messageType = "ADT^A01";

    // Constants for HL7v2 segments
    string processingId = "P";
    string versionId = "2.3";

    // MSH Segment
    string mshSegment = string `MSH|^~\\&|${sendingApp}|${sendingFacility}|${receivingApp}|${receivingFacility}|${messageDateTime}||${messageType}|${messageControlId}|${processingId}|${versionId}`;

    // PID Segment
    string pidSegment = string `PID|1||${patientId}^^^Hospital^MR||${familyName}^${givenName}||${birthDate}|${gender}|||${addressLine}^^${city}^${state}^${postalCode}|${phone}|||${gender}`;

    // Combine segments to create the HL7v2 message
    string hl7Message = mshSegment + "\n" + pidSegment;
    return hl7Message;
}

// Utility function to get current timestamp in HL7v2 format (YYYYMMDDHHMMSS)
isolated function getCurrentTimestamp() returns string {
    time:Utc currentTime = time:utcNow();
    return formatTimestamp(currentTime);
}

isolated function formatTimestamp(time:Utc timestamp) returns string {
    // Convert the UTC timestamp to a time:Civil record (this includes both date and time fields)
    time:Civil civil = time:utcToCivil(timestamp);

    // Extract the year, month, day, and time components
    string year = civil.year.toString();
    string month = civil.month < 10 ? "0" + civil.month.toString() : civil.month.toString();
    string day = civil.day < 10 ? "0" + civil.day.toString() : civil.day.toString();

    // Extract the time of day (hours, minutes, seconds)
    string hour = civil.hour < 10 ? "0" + civil.hour.toString() : civil.hour.toString();
    string minute = civil.minute < 10 ? "0" + civil.minute.toString() : civil.minute.toString();
    string second = <int>civil.second < 10 ? "0" : (<int>civil.second).toString();

    // Return the formatted timestamp as "YYYYMMDDHHMMSS"
    return year + month + day + hour + minute + second;
}

// Function to convert FHIR gender to HL7v2 gender format
isolated function getGenderHL7(string fhirGender) returns string|error {
    if fhirGender == "male" {
        return "M";
    } else if fhirGender == "female" {
        return "F";
    } else {
        return error("Invalid gender in FHIR resource");
    }
}
