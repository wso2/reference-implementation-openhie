import ballerinax/health.fhir.r4;
import ballerinax/health.fhir.r4.international401;
import ballerinax/health.hl7v2;
import ballerinax/health.hl7v24;

// Function to map a FHIR Patient resource to HL7v2
public isolated function mapFhirPatientToHL7(
        international401:Patient fhirPatient,
        string sendingApp,
        string sendingFacility,
        string receivingApp,
        string receivingFacility,
        string messageControlId) returns byte[]|error {
    // Transforming the FHIR Patient resource to HL7v2
    hl7v24:RSP_K21 queryResult = check transform(fhirPatient, sendingApp, sendingFacility, receivingApp, receivingFacility, messageControlId);
    // Encoding the HL7 message
    byte[] encodedMsg = check hl7v2:encode(hl7v24:VERSION, queryResult);
    return encodedMsg;
}

isolated function transform(international401:Patient fhirPatient,
        string sendingApp,
        string sendingFacility,
        string receivingApp,
        string receivingFacility,
        string messageControlId) returns hl7v24:RSP_K21|error =>
        
        let
        r4:HumanName[] name = check fhirPatient.name.ensureType(),
        string familyName = check name[0].family.ensureType(),
        string givenName = string:'join(" ", ...check name[0].given.ensureType()),
        string gender = fhirPatient.gender.toString() == "male" ? "M" : "F",

        r4:Address[] address = check fhirPatient.address.ensureType(),
        string addressLine = string:'join(" ", ...check address[1].line.ensureType()),
        string district = check address[0].district.ensureType(),
        string city = check address[1].city.ensureType(),
        string state = check address[1].state.ensureType(),
        string postalCode = check address[1].postalCode.ensureType(),

        r4:ContactPoint[] phone_ = check fhirPatient.telecom.ensureType(),
        string phone = phone_[0].value == () ? "" : check phone_[0].value.ensureType(),

        string messageDateTime = getCurrentTimestamp()
    in {
        msh: {
            msh2: "^~\\&",
            msh3: {
                hd1: sendingApp
            },
            msh4: {
                hd1: sendingFacility
            },
            msh5: {
                hd1: receivingApp
            },
            msh6: {
                hd1: receivingFacility
            },
            msh7: {
                ts1: messageDateTime
            },
            msh9: {
                msg1: "RSP^K21"
            },
            msh10: messageControlId,
            msh11: {
                pt1: "P"
            },
            msh12: {
                vid1: "2.4"
            }
        },
        qpd: {
            qpd1: {
                ce1: "IHE PDQ Query"
            },
            qpd2: messageControlId
        },
        msa: {
            msa1: "AA",
            msa2: messageControlId
        },
        qak: {
            qak1: "12345",
            qak2: "OK"
        },
        query_response: [
            {
                pid: {
                    pid1: "1",
                    pid3: [
                        {
                            cx1: <string>fhirPatient.id,
                            cx4: {
                                hd1: "Hospital",
                                hd2: "MR"
                            }
                        }
                    ],
                    pid5: [
                        {
                            xpn1: {fn1: familyName},
                            xpn2: givenName
                        }
                    ],
                    pid7: {
                        ts1: fhirPatient.birthDate.toString()
                    },
                    pid8: gender,
                    pid11: [
                        {
                            xad1: {
                                sad1: addressLine
                            },
                            xad3: city,
                            xad4: state,
                            xad5: postalCode
                        }
                    ],
                    pid13: [
                        {
                            xtn1: phone
                        }
                    ]
                }
            }
        ]
    };
