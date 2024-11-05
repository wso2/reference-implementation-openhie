import ballerinax/health.fhir.r4;
import ballerinax/health.fhir.r4.international401;

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
    string gender = fhirPatient.gender.toString() == "male" ? "M" : "F";
    string birthDate = fhirPatient.birthDate.toString();

    // Address Data
    r4:Address[] address = check fhirPatient.address.ensureType();
    string addressLine = string:'join(" ", ...check address[1].line.ensureType());
    string district = check address[0].district.ensureType();
    string city = check address[1].city.ensureType();
    string state = check address[1].state.ensureType();
    string postalCode = check address[1].postalCode.ensureType();

    // Telecom (phone) data
    r4:ContactPoint[] phone_ = check fhirPatient.telecom.ensureType();
    string phone = phone_[0].value == () ? "" : check phone_[0].value.ensureType();

    // Message date-time
    string messageDateTime = getCurrentTimestamp();

    // For patient admit events
    string messageType = "RSP^K21";

    // Constants for HL7v2 segments
    string processingId = "P";
    string versionId = "2.3";

    // MSH Segment
    string mshSegment = string `MSH|^~\\&|${sendingApp}|${sendingFacility}|${receivingApp}|${receivingFacility}|${messageDateTime}||${messageType}|${messageControlId}|${processingId}|${versionId}`;

    // PID Segment
    string pidSegment = string `PID|1||${patientId}^^^Hospital^MR||${familyName}^${givenName}||${birthDate}|${gender}|||${addressLine}^^${city}^${state}^${postalCode}|${district}|||${gender}`; // TODO:check again format: Phone , Disctrict

    // Combine segments to create the HL7v2 message
    string hl7Message = mshSegment + "\n" + pidSegment;
    return hl7Message;
}
