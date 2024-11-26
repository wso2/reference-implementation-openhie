import ballerinax/health.fhir.r4;
import ballerinax/health.fhir.r4.international401;
import ballerinax/health.hl7v2;
import ballerinax/health.hl7v24;

const string HL7_VERSION = "2.4";
const string MESSAGE_TYPE = "RSP^K21";
const string QUERY_NAME = "IHE PDQ Query";

public isolated function mapFhirPatientToHL7(
        international401:Patient fhirPatient,
        string sendingApp,
        string sendingFacility,
        string receivingApp,
        string receivingFacility,
        string messageControlId
) returns byte[]|error {
    hl7v24:RSP_K21 queryResult = check transform(
            fhirPatient, sendingApp, sendingFacility, receivingApp, receivingFacility, messageControlId
    );
    return check hl7v2:encode(HL7_VERSION, queryResult);
}

// Transform FHIR Patient to HL7v2 message
isolated function transform(
        international401:Patient fhirPatient,
        string sendingApp,
        string sendingFacility,
        string receivingApp,
        string receivingFacility,
        string messageControlId
) returns hl7v24:RSP_K21|error =>

    let
    r4:HumanName[] name = check fhirPatient.name.ensureType(),
    string familyName = name[0]?.family ?: "Unknown",
    string givenName = joinStrings(name[0]?.given ?: []),
    r4:Address[] address = check fhirPatient.address.ensureType(),
    string addressLine = joinStrings(address[0]?.line ?: []),
    string city = address[0]?.city ?: "Unknown",
    string state = address[0]?.state ?: "Unknown",
    string postalCode = address[0]?.postalCode ?: "Unknown",
    r4:ContactPoint[] telecom = check fhirPatient.telecom.ensureType(),
    string phone = telecom.length() > 0 && telecom[0]?.value is string ? <string>telecom[0].value : "Unknown",
    string gender = fhirPatient.gender.toString() == "male" ? "M" : fhirPatient.gender.toString() == "female" ? "F" : "U",
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
                msg1: MESSAGE_TYPE
            },
            msh10: messageControlId,
            msh11: {
                pt1: "P"
            },
            msh12: {
                vid1: HL7_VERSION
            }
        },
        qpd: {
            qpd1: {
                ce1: QUERY_NAME
            },
            qpd2: messageControlId
        },
        msa: {
            msa1: "AA",
            msa2: messageControlId
        },
        qak: {
            qak1: messageControlId,
            qak2: "OK"
        },
        query_response: [
            {
                pid: {
                    pid1: "1",
                    pid3: [
                        {
                            cx1: fhirPatient.id ?: "Unknown",
                            cx4: {
                                hd1: "Hospital",
                                hd2: "MR"
                            }
                        }
                    ],
                    pid5: [
                        {
                            xpn1: {
                                fn1: familyName
                            },
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
