# Usage

$ wget http://www.statmt.org/europarl/v7/europarl.tgz
$ tar xf europarl.tgz
$ git clone https://github.com/furlongm/europarl-parser
$ ./europarl-parser.sh -p
$ ./europarl-parser.sh -c
 or
$ ./europarl-parser.sh -c -f txt/en/ep-2010-07-07.txt
 or
$ ./europarl-parser.sh -c -l es

Processed files will end up in europarl/txt/lang/processed


# Links

http://www.statmt.org/europarl/
European Parliament Proceedings Parallel Corpus
The Europarl parallel corpus is extracted from the proceedings of the European Parliament.

http://www.ecpc.uji.es/
ECPC: European Comparable and Parallel Corpora
XML DTD for europarl corpus provided by ECPC

http://modnlp.sourceforge.net/
MODNLP: Modular Suite of NLP Tools
The output files can be processed by MODNLP (and converted to ARFF)

http://www.cs.waikato.ac.nz/ml/weka/
Weka: Data Mining Software in Java
The ARFF files can be imported into Weka for analysis


# Future enhancements (to be done)
* xsl file - when President etc is encountered in a NAME tag
  remove it and add it to POST tag
* currently only removes phrases in english
* currently only recognises WRITING in english (by finding "riting"
  in AFFILIATION tag
* instead of removing certain phrases, add an OMIT tag
* remove bogus elements from NAME tag
* fix xsl transform so a second 'indentation' xsl is not needed
* party affiliation can be described using the english or french
  abbreviation. add code to use one or the other. wikipedia
  typically has both abbreviations listed for each party.
* replace Greek keyboard UTF-8 characters (currently handled modnlp)
* fix "has been taken over by" in NAME tag

