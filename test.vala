#!/usr/bin/env vala
message ("hello world!");

Regex regexp = new Regex(".*(?:\\s|\\R)*(?P<message>(?:.|\\R)*?)\\s*$");


var m = "hello world\r\n  Riti toti.\r\nasdf adfa      \r\n   a    \r\n            ";
MatchInfo minfo;

if (regexp.match(m, 0, out minfo))
{
   var mes = minfo.fetch_named("message");
   message(":"+mes+":");
}

