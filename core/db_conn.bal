import ballerina/io;
import ballerinax/mongodb;

configurable DBConfig dBConfig = ?;

final mongodb:Client mongoClient = check new ({
    connection: {
        serverAddress: {
            host: dBConfig.host,
            port: dBConfig.port
        }
        // auth: <mongodb:ScramSha256AuthCredential>{
        //     username: dBConfig.username,
        //     password: dBConfig.password,
        //     database: dBConfig.dbname
        // }
    }
});

public isolated function saveAuditMessage(AuditMessage auditMessage) returns error? {
    mongodb:Database db = check mongoClient->getDatabase(dBConfig.dbname);
    mongodb:Collection auditCollection = check db->getCollection("audit");

    check auditCollection->insertOne(auditMessage);
    io:println("Audit message saved successfully");
}
