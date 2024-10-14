import ballerina/io;

public function splitString(string str, string delimiter) returns string[] {
    return re `${delimiter}`.split(str);
}

public function main() returns error? {

    string[] result = splitString("test/bal", "/");
    foreach string s in result {
        io:println(s);
    }

}
