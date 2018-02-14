# Smart Link Remover
## General
The Plugins removes any Link or IP Address from a Players Name

## Installation
Drag and Drop all Files into the appropriate Directories

## Config
```
"SmartLinkRemover Whitelist"
{
//  "URL"  "FLAGS"
//  "google.com"  ""
//  "my.clan"  "b"
//  "site.com"  "opqr"
}
```
// => Comment
In the First Quotes put the Whitelisted Phrase/Site
In the Second Quotes put the Flags or Flags you want the Phrases/Sites to be allowed

## Regex
The Following expression is used to identify unwanted Sites/IPs/Phrases in a Players Name
```
([ ]*[0-9]{1,3}[.][0-9]{1,3}[.][0-9]{1,3}[.][0-9]{1,3}[:0-9]{0,6})|([ ]*[-a-zA-Z0-9]*(([.])([a-zA-Z]){2,5}))
```
###Notes: 

[ ]* => ensures SMAC Compatibility
( https://forums.alliedmods.net/showpost.php?p=2578145&postcount=52 )

([ ]*[0-9]{1,3}[.][0-9]{1,3}[.][0-9]{1,3}[.][0-9]{1,3}[:0-9]{0,6}) => Captures IP:Port or only Ip

([ ]*[-a-zA-Z0-9]*(([.])([a-zA-Z]){2,5})) => Captures a Website URL



If you wish to modify the Regex or verify you may use https://regex101.com/ (select javascript)  
