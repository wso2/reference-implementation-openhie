import ballerinax/health.fhir.r4;

final r4:ResourceAPIConfig patientApiConfig = {
    resourceType: "Patient",
    
    profiles: [
        "https://profiles.ihe.net/ITI/PDQm/StructureDefinition/IHE.PDQm.Patient",
            
        "https://profiles.ihe.net/ITI/PDQm/StructureDefinition/IHE.PDQm.MatchInputPatient"
        

    ],
    defaultProfile: (),
    searchParameters: [
        {
            name: "family",
            active: true,
            information: {
                description: "**A portion of the family name of the patient**  **NOTE**: This US Core SearchParameter definition extends the usage context of the[Conformance expectation extension](http://hl7.org/fhir/R4/extension-capabilitystatement-expectation.html) - multipleAnd - multipleOr - comparator - modifier - chain",
                builtin: false,
                documentation: "http://hl7.org/fhir/us/core/SearchParameter/us-core-patient-family"
            }
        },
        {
            name: "name",
            active: true,
            information: {
                description: "**A server defined search that may match any of the string fields in the HumanName, including family, give, prefix, suffix, suffix, and/or text**  **NOTE**: This US Core SearchParameter definition extends the usage context of the[Conformance expectation extension](http://hl7.org/fhir/R4/extension-capabilitystatement-expectation.html) - multipleAnd - multipleOr - comparator - modifier - chain",
                builtin: false,
                documentation: "http://hl7.org/fhir/us/core/SearchParameter/us-core-patient-name"
            }
        },
        {
            name: "gender-identity",
            active: true,
            information: {
                description: "Returns patients with an gender-identity extension matching the specified code.",
                builtin: false,
                documentation: "http://hl7.org/fhir/us/core/SearchParameter/us-core-patient-gender-identity"
            }
        },
        {
            name: "ethnicity",
            active: true,
            information: {
                description: "Returns patients with an ethnicity extension matching the specified code.",
                builtin: false,
                documentation: "http://hl7.org/fhir/us/core/SearchParameter/us-core-ethnicity"
            }
        },
        {
            name: "race",
            active: true,
            information: {
                description: "Returns patients with a race extension matching the specified code.",
                builtin: false,
                documentation: "http://hl7.org/fhir/us/core/SearchParameter/us-core-race"
            }
        },
        {
            name: "given",
            active: true,
            information: {
                description: "**A portion of the given name of the patient**  **NOTE**: This US Core SearchParameter definition extends the usage context of the[Conformance expectation extension](http://hl7.org/fhir/R4/extension-capabilitystatement-expectation.html) - multipleAnd - multipleOr - comparator - modifier - chain",
                builtin: false,
                documentation: "http://hl7.org/fhir/us/core/SearchParameter/us-core-patient-given"
            }
        },
        {
            name: "identifier",
            active: true,
            information: {
                description: "**A patient identifier**  **NOTE**: This US Core SearchParameter definition extends the usage context of the[Conformance expectation extension](http://hl7.org/fhir/R4/extension-capabilitystatement-expectation.html) - multipleAnd - multipleOr - comparator - modifier - chain",
                builtin: false,
                documentation: "http://hl7.org/fhir/us/core/SearchParameter/us-core-patient-identifier"
            }
        },
        {
            name: "_id",
            active: true,
            information: {
                description: "**Logical id of this artifact**  **NOTE**: This US Core SearchParameter definition extends the usage context of the[Conformance expectation extension](http://hl7.org/fhir/R4/extension-capabilitystatement-expectation.html) - multipleAnd - multipleOr - comparator - modifier - chain",
                builtin: false,
                documentation: "http://hl7.org/fhir/us/core/SearchParameter/us-core-patient-id"
            }
        },
        {
            name: "gender",
            active: true,
            information: {
                description: "**Gender of the patient**  **NOTE**: This US Core SearchParameter definition extends the usage context of the[Conformance expectation extension](http://hl7.org/fhir/R4/extension-capabilitystatement-expectation.html) - multipleAnd - multipleOr - comparator - modifier - chain",
                builtin: false,
                documentation: "http://hl7.org/fhir/us/core/SearchParameter/us-core-patient-gender"
            }
        },
        {
            name: "birthdate",
            active: true,
            information: {
                description: "**The patient's date of birth**  **NOTE**: This US Core SearchParameter definition extends the usage context of the[Conformance expectation extension](http://hl7.org/fhir/R4/extension-capabilitystatement-expectation.html) - multipleAnd - multipleOr - comparator - modifier - chain",
                builtin: false,
                documentation: "http://hl7.org/fhir/us/core/SearchParameter/us-core-patient-birthdate"
            }
        },
        {
            name: "_count",
            active: true,
            information: {
                description: "Number of results per page",
                builtin: false,
                documentation: "http://hl7.org/fhir/search.html#count"
            }
        },
        {
            name: "_offset",
            active: true,
            information: {
                description: "Starting offset for pagination",
                builtin: false,
                documentation: "http://hl7.org/fhir/search.html#count"
            }
        },
        {
            name: "patient1",
            active: true,
            information: {
                description: "First patient ID for dedup match rejection",
                builtin: false,
                documentation: "Custom parameter for dedup rejection endpoint"
            }
        },
        {
            name: "patient2",
            active: true,
            information: {
                description: "Second patient ID for dedup match rejection",
                builtin: false,
                documentation: "Custom parameter for dedup rejection endpoint"
            }
        },
        {
            name: "active",
            active: true,
            information: {
                description: "Whether the patient record is active",
                builtin: false,
                documentation: "http://hl7.org/fhir/SearchParameter/Patient-active"
            }
        },
        {
            name: "telecom",
            active: true,
            information: {
                description: "The value in any kind of telecom details of the patient",
                builtin: false,
                documentation: "http://hl7.org/fhir/SearchParameter/Patient-telecom"
            }
        },
        {
            name: "address",
            active: true,
            information: {
                description: "An address in any kind of address/part of the patient",
                builtin: false,
                documentation: "http://hl7.org/fhir/SearchParameter/individual-address"
            }
        },
        {
            name: "address-city",
            active: true,
            information: {
                description: "A city specified in an address",
                builtin: false,
                documentation: "http://hl7.org/fhir/SearchParameter/individual-address-city"
            }
        },
        {
            name: "address-country",
            active: true,
            information: {
                description: "A country specified in an address",
                builtin: false,
                documentation: "http://hl7.org/fhir/SearchParameter/individual-address-country"
            }
        },
        {
            name: "address-postalcode",
            active: true,
            information: {
                description: "A postalCode specified in an address",
                builtin: false,
                documentation: "http://hl7.org/fhir/SearchParameter/individual-address-postalcode"
            }
        },
        {
            name: "address-state",
            active: true,
            information: {
                description: "A state specified in an address",
                builtin: false,
                documentation: "http://hl7.org/fhir/SearchParameter/individual-address-state"
            }
        },
        {
            name: "mothersMaidenName",
            active: true,
            information: {
                description: "Mother's maiden name of the patient",
                builtin: false,
                documentation: "http://hl7.org/fhir/SearchParameter/patient-extensions-Patient-mothersMaidenName"
            }
        }
    ],
    operations: [

        {
            name: "export",
            active: true,
            parameters: [
                {
                    name: "_outputFormat",
                    active: true,
                    min: 0
                },
                {
                    name: "_since",
                    active: true,
                    min: 0
                },
                {
                    name: "_type",
                    active: true,
                    min: 0
                },
                {
                    name: "_elements",
                    active: true,
                    min: 0
                },
                {
                    name: "patient",
                    active: true,
                    min: 0
                },
                {
                    name: "includeAssociatedData",
                    active: true,
                    min: 0
                },
                {
                    name: "_typeFilter",
                    active: true,
                    min: 0
                }
            ]
        },
        {
            name: "match",
            active: true,
            parameters: [
                {
                    name: "resource",
                    active: true,
                    min: 1
                },
                {
                    name: "onlyCertainMatches",
                    active: true,
                    min: 0
                },
                {
                    name: "count",
                    active: true,
                    min: 0
                }
            ]
        },
        {
            name: "member-match",
            active: true,
            parameters: [
                {
                    name: "MemberPatient",
                    active: true,
                    min: 1
                },
                {
                    name: "Consent",
                    active: true,
                    min: 1
                },
                {
                    name: "CoverageToMatch",
                    active: true,
                    min: 1
                },
                {
                    name: "CoverageToLink",
                    active: true
                }
            ]
        }
    ],
    serverConfig: (),
    authzConfig: (),
    auditConfig: {
        enabled: false,
        auditServiceUrl: auditServiceUrl
    }
};
