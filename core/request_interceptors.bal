import ballerina/http;

public isolated service class ValidateInterceptor {
    *http:RequestInterceptor;

    isolated resource function 'default [string... path](http:RequestContext ctx, http:Request req) returns http:NextService|error? {
        // TODO: Implement request validation logic
        return ctx.next();
    }
}

public isolated service class AuditInterceptor {
    *http:RequestInterceptor;

    isolated resource function 'default [string... path](http:RequestContext ctx, http:Request req) returns http:NextService|error? {
        AuditMessage auditMsg = generateLoginAuditMessage("Success", "sysname", "username", "userRole", "userRoleCode");
        check saveAuditMessage(auditMsg);
        return ctx.next();
    }
}
