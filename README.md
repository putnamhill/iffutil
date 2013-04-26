The purpose of these utilities is to maintain a serialized text version of iff files to help with version control systems.

`bin/iff2xml.pl`  - converts iff files to xml (iff2xml.pl -h for usage)
`bin/xml2iff.pl`* - converts xml files to iff (xml2iff.pl -h for usage)
`bin/pre-commit`  - git hook that converts any new iff file to xml
`bin/post-checkout` - git hook that converts all xml files back to iff

* `xml2iff.pl` requires XML::Twig (http://search.cpan.org/perldoc?XML::Twig)
If xml2iff.pl prints `Can't locate XML/Twig.pm in @INC (@INC contains:...` then you'll need the XML::Twig module.

To test the utilities compare the converted/reconverted output to the original file:
    iff2xml.pl test.dir | xml2iff.pl -o - | diff -s - test.dir
    Files - and test.dir are identical

If the files - and test.dir are NOT identical, then there is a problem.
