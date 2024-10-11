import ballerina/http;

public isolated service class MessageFormatterIntercepter {
    *http:ResponseInterceptor;

    isolated remote function interceptResponse(http:RequestContext ctx, http:Response res) returns http:NextService|error? {
        string in_content_type = ctx.get("in-content-type").toString();
        MessageFormatter messageFormatter = check getMessageFormatter(in_content_type);
        http:Response newRes = check messageFormatter.format(res);
        byte[] payload = check newRes.getBinaryPayload();
        res.setPayload(payload, newRes.getContentType());
        return ctx.next();
    }
}
