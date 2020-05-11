#!/bin/bash
#
# (c) 2011 Marcus Furlong <furlongm@gmail.com>
# Licensed under the GNU GENERAL PUBLIC LICENSE Version 2 (GPLv2)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 2 only.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
#
# Typical usage
# -------------
# $ wget http://www.statmt.org/europarl/v7/europarl.tgz
# $ tar xf europarl.tgz
# $ git clone https://github.com/furlongm/europarl-parser
# $ ./europarl-parser.sh -p
# $ ./europarl-parser.sh -c
#  or
# $ ./europarl-parser.sh -c -f txt/en/ep-2010-07-07.txt
#  or
# $ ./europarl-parser.sh -c -l es
#
# Processed files will end up in europarl/txt/lang/processed
#
#
# Links
# -----
# http://www.statmt.org/europarl/
# European Parliament Proceedings Parallel Corpus
# The Europarl parallel corpus is extracted from the proceedings of the European Parliament.
#
# http://www.ecpc.uji.es/
# ECPC: European Comparable and Parallel Corpora
# XML DTD for europarl corpus provided by ECPC
#
# http://modnlp.sourceforge.net/
# MODNLP: Modular Suite of NLP Tools
# The output files can be processed by MODNLP (and converted to ARFF)
#
# http://www.cs.waikato.ac.nz/ml/weka/
# Weka: Data Mining Software in Java
# The ARFF files can be imported into Weka for analysis
#
#
# Future enhancements (to be done)
# -------------------------
# * xsl file - when President etc is encountered in a NAME tag
#   remove it and add it to POST tag
# * currently only removes phrases in english
# * currently only recognises WRITING in english (by finding "riting"
#   in AFFILIATION tag
# * instead of removing certain phrases, add an OMIT tag
# * remove bogus elements from NAME tag
# * fix xsl transform so a second 'indentation' xsl is not needed
# * party affiliation can be described using the english or french
#   abbreviation. add code to use one or the other. wikipedia
#   typically has both abbreviations listed for each party.
# * replace Greek keyboard UTF-8 characters (currently handled modnlp)
# * fix "has been taken over by" in NAME tag

# User variables

# set to 1 to skip files that have already been processed
skip_existing=1

# set to 1 to rename files to e.g. EN20031222.xml
rename_files=1

# Set the default language to process
lang=en

# Each language directory needs to be validated against a separate language,
# because all the native language interventions will be marked as UNKNOWN.
# e.g. in the 'en' directory, all interventions that should be marked
# LANGUAGE="EN" are in fact marked LANAGUAGE="UNKNOWN".
# So we validate these against another language directory where they are
# correctly attributed. Either set this here and run the preprocesser against
# those language directories. If not set, it will scan all other-language
# directories for the correct files.
alt_langs=

# Where to output the processed xml files
base_output_dir=xml

# Temporary directory to use
tmp_dir=/tmp

# set to 1 to remove temporary files, 0 otherwise
remove_tmp_files=0


usage() {
    echo
    echo "This script converts Europarl Parallel Corpus txt files to ep.dtd-compliant xml"
    echo "See comments in script for futher information."
    echo
    echo "Usage:"
    echo "${0} -p           (preprocesses files)"
    echo "${0} -c           (converts all files - defaults to language en)"
    echo "${0} -c -f FILE   (converts a single file to ecpc_EP xml)"
    echo "${0} -c -l es     (converts all files for a given language, e.g. Spanish)"
    echo
    echo "This script assumes the europarl corpus has been extracted to the current directory"
    echo
    echo "Preprocessing files takes some time, but will significantly increase the number"
    echo "of files processed. Only files of the format ep-yy-mm-dd.txt will be processed,"
    echo "and in later years, these files have been split out into a number of smaller"
    echo "files which will not be converted unless preprocessing is run before conversion."
    echo
    exit 0
}

create_scratch_dir() {
    mkdir -p ${tmp_dir}/europarl-parser/${USER}/
    scratch_dir=$(mktemp -d -t -p ${tmp_dir}/europarl-parser/${USER})
    if [ "$?" != "0" ] ; then
        echo "Problem creating temporary directory, is mktemp installed?"
        usage
    fi
}

delete_scratch_dir() {
    if [ "remove_tmp_files" == "1" ] ; then
        rm -fr ${scratch_dir}
    fi
}

output_dtd() {
    if [ ! -e ep.dtd ] ; then
        cat > ep.dtd << EOF
<!-- ep.dtd: EC Parliament sessions. $Revision: 1.7 $ -->
<!ELEMENT ecpc_EP (header,body,back)>
<!ELEMENT header (title|index|omit)*>
<!ATTLIST header filename CDATA #REQUIRED>
<!ATTLIST header language (BG|CS|DA|DE|EL|EN|ES|ET|FI|FR|GA|HU|IT|LT|LV|MT|NL|PL|PT|RO|SK|SL|SV) #REQUIRED>
<!ELEMENT title (#PCDATA)>
<!-- indexitem tags different items within the index. These will be repeated later on throughout the text as header to separate different items in the session -->
<!ELEMENT index (#PCDATA|label|date|place|edition|indexitem)*>
<!-- WHY CAN'T WE USE * NEXT TO INDEXITEM AND IN THE BRACKETS -->
<!ELEMENT label (#PCDATA)>
<!ELEMENT date (#PCDATA)>
<!ELEMENT place (#PCDATA)>
<!ELEMENT edition (#PCDATA)>
<!ELEMENT indexitem (#PCDATA)>
<!ATTLIST indexitem number CDATA #REQUIRED>
<!--All elements which are to part of speech and will be consequently omitted in our study will be labelled no speech when they appear outside the speech -->
<!ELEMENT omit (#PCDATA)>
<!--WE could add attributes to these list if we find more nospeech items -->
<!ATTLIST omit desc (opening|action|reaction|procedure|note|closing) #IMPLIED>
<!--Chair tags the person presiding the session over; opening is the time in which the session is opened; intervention contains information about speakers plus speeches; headings are the indexitems which now separate parts of the session; nospeech are items that are not part of the speech -->
<!ELEMENT body (#PCDATA|chair|intervention|heading|omit|italics)*>
<!ELEMENT chair (#PCDATA|omit)*>
<!--<!ELEMENT intervention (speaker|speech|writer|writing|omit|italics)*>-->
<!ELEMENT intervention (omit*,(speaker|writer),omit*,(speech|writing)+,omit*)>
<!ATTLIST intervention ref CDATA #IMPLIED>
<!ELEMENT speaker (name*,affiliation?,post?)>
<!ELEMENT name (#PCDATA)>
<!ELEMENT affiliation EMPTY>
<!ATTLIST affiliation
EPparty (PPE-DE|PSE|ALDE|Verts-ALE|GUE-NGL|IND-DEM|UEN|NI|ELDR|EDD|EPP-ED|PPE|UPE|TDI|I-EDN|ARE|EFD|ITS|ECR|S-D|UNKNOWN) "UNKNOWN"
national_party CDATA #IMPLIED>
<!ELEMENT post (#PCDATA)>
<!ELEMENT speech (#PCDATA|omit|italics)*>
<!ATTLIST speech language (BG|CS|DA|DE|EL|EN|ES|ET|FI|FR|GA|HU|IT|LT|LV|MT|NL|PL|PT|RO|SK|SL|SV|UNKNOWN)
"UNKNOWN">
<!ATTLIST speech ref ID #REQUIRED>
<!ELEMENT writer (name*,affiliation?,post?)>
<!ELEMENT writing (#PCDATA|omit|italics)*>
<!ATTLIST writing ref ID #REQUIRED>
<!ATTLIST writing language (BG|CS|DA|DE|EL|EN|ES|ET|FI|FR|GA|HU|IT|LT|LV|MT|NL|PL|PT|RO|SK|SL|SV|UNKNOWN)
"UNKNOWN">
<!ELEMENT italics (#PCDATA)>
<!ELEMENT heading (#PCDATA)>
<!ATTLIST heading number CDATA #REQUIRED>
<!ELEMENT back (update|disclaimer|omit)*>
<!ELEMENT update (#PCDATA)>
<!ELEMENT disclaimer (#PCDATA)>
EOF
    fi;
}

output_xslt() {
    if [ ! -e ep.dtd.xsl ] ; then
        cat > ep.dtd.xsl << EOF
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:str="http://exslt.org/strings"
                extension-element-prefixes="str">

<xsl:output method="xml"
    doctype-system="ep.dtd"
    cdata-section-elements="script style"
    indent="yes"
    encoding="UTF-8" />

<xsl:template match="body">
<ecpc_EP>
<header>
  <xsl:attribute name="filename">
    <xsl:value-of select="filename/@id" />
  </xsl:attribute>
  <xsl:attribute name="language">
    <xsl:value-of select="language/@id" />
  </xsl:attribute>
</header>
<body>
<xsl:apply-templates />
</body><back />
</ecpc_EP>
</xsl:template>

<xsl:template match="SPEAKER">
<intervention>
<xsl:text>
</xsl:text>
  <xsl:choose>
    <xsl:when test="contains(@AFFILIATION,'riting') or contains(@AFFILIATION,'ritten')">
      <writer>
<xsl:text>
</xsl:text>
        <name>
          <xsl:choose>
            <xsl:when test="contains(@NAME,'(')">
              <xsl:value-of select="normalize-space(str:replace(substring-before(@NAME,'('),',',' '))" />
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="normalize-space(str:replace(@NAME,',',' '))" />
            </xsl:otherwise>
          </xsl:choose>
        </name>
<xsl:text>
</xsl:text>
        <affiliation>
          <xsl:choose>
            <xsl:when test="contains(@NAME,'(')">
              <xsl:attribute name="EPparty">
                <xsl:value-of select="normalize-space(str:replace(substring-before(substring-after(@NAME,'('),')'),'/','-'))" />
              </xsl:attribute>
            </xsl:when>
            <xsl:otherwise>
              <xsl:attribute name="EPparty">
                <xsl:value-of select="normalize-space(str:replace(@AFFILIATION,'/','-'))" />
              </xsl:attribute>
            </xsl:otherwise>
          </xsl:choose>
        </affiliation>
<xsl:text>
</xsl:text>
        <post />
<xsl:text>
</xsl:text>
      </writer>
<xsl:text>
</xsl:text>
      <writing>
        <xsl:attribute name="ref">
          <xsl:value-of select="concat('w',@ID)" />
        </xsl:attribute>
        <xsl:attribute name="language">
        <xsl:choose>
          <xsl:when test="@LANGUAGE!=''">
              <xsl:value-of select="@LANGUAGE" />
          </xsl:when>
          <xsl:otherwise>
              <xsl:text>UNKNOWN</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:value-of select="normalize-space(.)" />
    </writing>
    </xsl:when>
    <xsl:otherwise>
      <speaker>
<xsl:text>
</xsl:text>
        <name>
          <xsl:choose>
            <xsl:when test="contains(@NAME,'(')">
              <xsl:value-of select="normalize-space(str:replace(substring-before(@NAME,'('),',',' '))" />
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="normalize-space(str:replace(@NAME,',',' '))" />
            </xsl:otherwise>
          </xsl:choose>
        </name>
<xsl:text>
</xsl:text>
        <affiliation>
          <xsl:choose>
            <xsl:when test="contains(@NAME,'(')">
              <xsl:attribute name="EPparty">
                <xsl:value-of select="normalize-space(str:replace(substring-before(substring-after(@NAME,'('),')'),'/','-'))" />
              </xsl:attribute>
            </xsl:when>
            <xsl:otherwise>
              <xsl:attribute name="EPparty">
                <xsl:value-of select="normalize-space(str:replace(@AFFILIATION,'/','-'))" />
              </xsl:attribute>
            </xsl:otherwise>
          </xsl:choose>
        </affiliation>
<xsl:text>
</xsl:text>
        <post />
<xsl:text>
</xsl:text>
      </speaker>
<xsl:text>
</xsl:text>
      <speech>
        <xsl:attribute name="ref">
          <xsl:value-of select="concat('s',@ID)" />
        </xsl:attribute>
        <xsl:attribute name="language">
        <xsl:choose>
          <xsl:when test="@LANGUAGE!=''">
              <xsl:value-of select="@LANGUAGE" />
          </xsl:when>
          <xsl:otherwise>
              <xsl:text>UNKNOWN</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:value-of select="normalize-space(.)" />
    </speech>
  </xsl:otherwise>
  </xsl:choose>
</intervention>
<xsl:text>
</xsl:text>
</xsl:template>

</xsl:stylesheet>
EOF
    fi
}

output_indent() {
    if [ ! -e indent.xsl ] ; then
        cat > indent.xsl << EOF
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" encoding="UTF-8"/>
  <xsl:param name="indent-increment" select="'   '"/>
  <xsl:template name="newline">
    <xsl:text disable-output-escaping="yes">
</xsl:text>
  </xsl:template>
  <xsl:template match="comment() | processing-instruction()">
    <xsl:param name="indent" select="''"/>
    <xsl:call-template name="newline"/>
    <xsl:value-of select="\$indent"/>
    <xsl:copy />
  </xsl:template>
  <xsl:template match="text()">
    <xsl:param name="indent" select="''"/>
    <xsl:call-template name="newline"/>
    <xsl:value-of select="\$indent"/>
    <xsl:value-of select="normalize-space(.)"/>
  </xsl:template>
  <xsl:template match="text()[normalize-space(.)='']"/>
  <xsl:template match="*">
    <xsl:param name="indent" select="''"/>
    <xsl:call-template name="newline"/>
    <xsl:value-of select="\$indent"/>
      <xsl:choose>
       <xsl:when test="count(child::*) > 0">
        <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates select="*|text()">
           <xsl:with-param name="indent" select="concat (\$indent, \$indent-increment)"/>
         </xsl:apply-templates>
         <xsl:call-template name="newline"/>
         <xsl:value-of select="\$indent"/>
        </xsl:copy>
       </xsl:when>
       <xsl:otherwise>
        <xsl:copy-of select="."/>
       </xsl:otherwise>
     </xsl:choose>
  </xsl:template>
</xsl:stylesheet>
EOF
    fi
}

find_new_lang() {
    for l in ${alt_langs} ; do
        if [ -f ../${l}/${filename} ] ; then
            alt_lang_file=../${l}/${filename}
        else
            continue
        fi
        cp ${alt_lang_file} ${tmp_file}.altlang
        unset alt_lang_file

        sed -i -e 's/ID=\([0-9]\+\)/ID="\1"/g' ${tmp_file}.altlang

        # add alternate style (FR) languages in the text into the LANGUAGE attribute
        sed -i -r -n '/>/{N; s/\n//; s/(KER ID="[0-9]+")(.*)>[^<]*\((BG|CS|DA|DE|EL|EN|ES|ET|FI|FR|GA|HU|IT|LT|LV|MT|NL|PL|PT|RO|SK|SL|SV)\)[ ]*/\1 LANGUAGE="\3"\2>/g;p;}' ${tmp_file}.altlang
        sed -i -e 's/> \?/>\n/g' ${tmp_file}.altlang

        # switch NAME and LANGUAGE attributes for newer files
        sed -i -e 's/\(NAME=".*"\)\(.*\)\(LANGUAGE=".*"\) *>/\3 \1\2>/g' ${tmp_file}.altlang

        # remove duplicate languages (the one in brackets is usually correct)
        sed -i -e 's/\(LANGUAGE="[A-Z][A-Z]"\) \1/\1/g' ${tmp_file}.altlang
        sed -i -e 's/\(LANGUAGE="[A-Z][A-Z]"\) LANGUAGE="[A-Z]*[A-Z]*"//g' ${tmp_file}.altlang
        sed -i -e 's/\(SPEAKER ID[^ ]*\)\( NAME=[^>]*>\)/\1 LANGUAGE=\"\"\2/g' ${tmp_file}.altlang

        new_lang=$(grep "${first_segment}" ${tmp_file}.altlang | cut -f4 -d\")
        rm ${tmp_file}.altlang

        if [ ! -z ${new_lang} ] ; then
            if [ "${new_lang}" == "UNKNOWN" ] || [ "${new_lang}" == "CA" ] || [ "${new_lang}" == "UN" ] ; then
                unset new_lang
            else
                break
            fi
        fi
    done
}

missing_languages() {
    OLDIFS=${IFS}
    IFS="
"
    sed -i -e 's/\(SPEAKER ID[^ ]*\)\( NAME=[^>]*>\)/\1 LANGUAGE=\"\"\2/g' ${tmp_file}
    for speaker_segment in $(grep "SPEAKER ID" ${tmp_file}) ; do
        unset new_lang
        old_lang=$(echo "${speaker_segment}" | cut -f4 -d\")
        first_segment=$(echo "${speaker_segment}" | cut -f1-3 -d\")
        if [ -z ${old_lang} ] ; then
            find_new_lang
            if [ ! -z ${new_lang} ] ; then
                second_segment=`echo $speaker_segment | sed -e 's/\\//\\\\\//g' -e 's/\\*//g' -e 's/\\[/\\\\[/g' -e 's/\\]/\\\\]/g'  | cut -f5- -d\"`
                sed -i -e "s/\(${first_segment}\"\).*\(\"${second_segment}\)/\1${new_lang}\2/" ${tmp_file}
            fi
        fi
    done
    IFS=${OLDIFS}
}

get_filenames() {
    base_filename=${filename/.txt}
    tmp_file=${scratch_dir}/${base_filename}.tmp
    tmp_xml_file=${scratch_dir}/${base_filename}.tmp.xml

    if [ "${rename_files}" != "1" ] ; then
        xml_filename=${base_filename}.xml
        return
    fi

    let year=10#$(echo ${base_filename} | cut -f 2 -d -)
    if [ ${year} -gt 95 ] ; then
        year=19${year}
    else
        if [ ${year} -lt 10 ] ; then
            year=200${year}
        else
            year=20${year}
        fi
    fi

    month=$(echo ${base_filename} | cut -f 3 -d -)
    day=$(echo ${base_filename} | cut -f 4 -d -)
    xml_filename=${language}${year}${month}${day}.xml
}

not_valid() {
    echo ". not valid, moving to ${xml_filename}.bad"
    mv ${output_dir}/${xml_filename} ${output_dir}/${xml_filename}.bad
}

is_valid() {
    echo -n ". (valid)"
    xsltproc -o ${output_dir}/${xml_filename} ${base_dir}/indent.xsl ${output_dir}/${xml_filename}
    echo " ${output_dir}/${xml_filename}"
}

english_phrases() {
    sed -i -e 's/VOTES*//g' \
    -e 's/(*Parliament adopted the resolution)*//g' \
    -e 's/(*Parliament adopted the Commission proposal)*//g' \
    -e 's/(*Approval of the Minutes)*//g' \
    -e 's/(*The Minutes were approved)*//g' \
    -e 's/(Applause[^)]*)//g' \
    -e 's/Applause//g' \
    -e 's/(*Murmurs of dissent)*//g' \
    -e 's/Draft Amendment No//g' \
    -e 's/(*Parliament adopted the legislative resolution)*//g' \
    -e 's/(*Parliament gave its assent)*//g' \
    -e 's/(*Parliament rejected the motion for a resolution)*//g' \
    -e 's/(The sitting was[^)]*)//g' \
    -e 's/(Parliament rejected the[^)]*)//g' \
    -e 's/(The President cut.*)//g' \
    -e 's/(*Vigorous applause)*//g' \
    -e 's/(*Loud applause)*//g' \
    -e 's/(The President interrupted[^)]*)//g' \
    -e 's/(The proposal[^)]*)//g' \
    -e 's/(Mixed reactions)//g' \
    -e 's/(Laughter and applause)//g' \
    -e 's/(Laughter)//g' \
    -e 's/(The oral amendment was[^)]*)//g' \
    -e 's/.* Report (.*\/[^)]*)//g' \
    -e 's/(Exclamations)//g' \
    -e 's/(Explanation of vote abbreviated[^)]*)//g' \
    -e 's/(Muted applause)//g' \
    -e 's/(Parliament[^)]*)//g' \
    -e 's/(The House[^)]*)//g' \
    -e 's/(*Adjournment of the session)*//g' ${tmp_file}
}

correct_bad_languages() {
    # verified by cross-referencing the other languages
    sed -i -e 's/LANGUAGE="SI"/LANGUAGE="SL"/g' \
           -e 's/LANGUAGE="NI"/LANGUAGE="FR"/g' \
           -e 's/LANGUAGE="NK"/LANGUAGE="NL"/g' \
           -e 's/LANGUAGE="GR"/LANGUAGE="EL"/g' \
           -e 's/LANGUAGE="ER"/LANGUAGE="EL"/g' \
           -e 's/LANGUAGE="SP"/LANGUAGE="ES"/g' \
           -e 's/LANGUAGE="NO"/LANGUAGE="NL"/g' \
           -e 's/LANGUAGE="IN"/LANGUAGE="IT"/g' \
           -e 's/LANGUAGE="UK"/LANGUAGE="EN"/g' \
           -e 's/LANGUAGE="UN"/LANGUAGE="EN"/g' \
           -e 's/LANGUAGE="CZ"/LANGUAGE="CS"/g' \
           -e 's/LANGUAGE="DK"/LANGUAGE="DA"/g' \
           -e 's/LANGUAGE="CA"//g'              \
           -e 's/LANGUAGE="EM"//g'              \
           ${tmp_file}
}

convert_file() {
    echo -n "Processing ${1} . "
    if [ ! -f ${1} ] ; then
        echo 'Error: file does not exist'
        return
    fi

    filename=$(basename ${1})
    let length=$(echo ${filename} | wc -c)
    if [ ${length} -ne 16 ] ; then
        echo 'Error: can only process files of format ep-10-10-10.txt'
        cd ${base_dir}
        return
    fi

    file_dir=$(dirname ${1})
    cd ${file_dir}
    language=${lang^^}
    output_dir=${base_dir}/${base_output_dir}/${lang}

    get_filenames

    if [ "${skip_existing}" == "1" ] && [ -f ${output_dir}/${xml_filename} ] ; then
        echo 'Warning: output file exists, skipping.'
        cd ${base_dir}
        return
    fi

    cp ${filename} ${tmp_file}

    # convert S&amp;D to S-D
    sed -i -e 's/S&amp;D/S-D/g' ${tmp_file}

    # add quotes to ID tags
    sed -i -e 's/ID=\([0-9]\+\)/ID="\1"/g' ${tmp_file}

    # add alternate style (FR) languages in the text into the LANGUAGE attribute
    sed -i -r -n '/>/{N; s/\n//; s/(KER ID="[0-9]+")(.*)>[^<]*\((BG|CS|DA|DE|EL|EN|ES|ET|FI|FR|GA|HU|IT|LT|LV|MT|NL|PL|PT|RO|SK|SL|SV)\)[ ]*/\1 LANGUAGE="\3"\2>/g;p;}' ${tmp_file}
    sed -i -e 's/> \?/>\n/g' ${tmp_file}

    # switch NAME and LANGUAGE attributes for newer files
    sed -i -e 's/\(NAME=".*"\)\(.*\)\(LANGUAGE=".*"\) *>/\3 \1\2>/g' ${tmp_file}

    # remove duplicate languages (the one in brackets is usually correct)
    sed -i -e 's/\(LANGUAGE="[A-Z][A-Z]"\) \1/\1/g' ${tmp_file}
    sed -i -e 's/\(LANGUAGE="[A-Z][A-Z]"\) LANGUAGE="[A-Z]*[A-Z]*"//g' ${tmp_file}

    english_phrases
    missing_languages
    correct_bad_languages

    # other common errors
    sed -i -e 's/&/and/g'                                     \
           -e 's/?ratsa-?sagaropoulou/Kratsa-Tsagaropoulou/g' \
           -e 's/S<nchez/Sánchez/g'                           \
           -e 's/PPE[–|_]DE/PPE-DE/g'                         \
           -e 's/()//g'                                       \
           -e 's/<0}*//g'                                     \
           -e 's/{0>//g'                                      \
           -e 's/ \.//g'                                      \
           -e 's/ –//g'                                       \
           -e 's/ / /g'                                       \
           -e 's/<-//g'                                       \
           ${tmp_file}

    # remove paragraphs, empty speaker elements, chapter elements
    # add quotes to non-quoted ID tags
    # FIXME: there are still empty speaker elements after this.
    sed -i -e 's/<SPEAKER.*\/>//g'                                        \
           -e 's/<\/*P.*>//g'                                             \
           -e '/<CHAPTER/{ :f; s/<CHAPTER.*\(<SPEAKER\)/\1/; t; N; bf; }' \
           ${tmp_file}

    sed -i '1i\
' ${tmp_file}

    perl -pi -e 'print "\n" if $. == 1; undef $/; s{(<(\w+).*?>.*?)(?=\s*(<\w|\z))}{$1."\n</$2>"}esg' ${tmp_file}

    # remove extra quotes in name element
    sed -i -e 's/\(NAME=".*\)"\(.*\)"\(.*"\)/\1\2\3/g' \
           -e 's/\(NAME=".*\)"\(.*\)"\(.*"\)/\1\2\3/g' \
           -e 's/\(NAME=\".*\)"\(.*\"\)/\1\2/g'        \
           -e "s/\(NAME=\".*\)'\(.*\"\)/\1\2/g"        \
           ${tmp_file}

    sed -i -e 's/\(NAME="[^"]*\) AFFILIATION=\([^"]*\)">/\1" AFFILIATION="\2">/g' ${tmp_file}

    output_xml
    transform_xml

    # this removes any EPparty attributes that don't match the DTD
    # if you change the DTD remember to change it here too
    sed -i -e 's/ EPparty="\(PPE-DE\|PSE\|ALDE\|Verts-ALE\|GUE-NGL\|IND-DEM\|UEN\|NI\|ELDR\|EDD\|EPP-DE\|PPE\|UPE\|TDI\|EFD\|ITS\|ECR\|S-D\|UNKNOWN\)"/@="\1"/g
               s/  *EPparty="[^"]*"//g
               s/@="/ EPparty="/g' ${output_dir}/${xml_filename}

    # Remove this for now. For future reference, sometimes the affiliation contains the post
    # sed -i -e 's/\(<name>.*\)AFFILIATION=.*\(<\/name>\)/\1\2/g' ${output_dir}/${xml_filename}

    xmllint --noout --valid ${output_dir}/${xml_filename} && is_valid || not_valid

    [[ "${remove_tmp_files}" == "1" ]] && rm -f ${tmp_file} ${tmp_xml_file}

    cd ${base_dir}
}

output_xml() {
    echo '<body>'                                    > ${tmp_xml_file}
    echo "<filename id=\"${xml_filename/.xml}\" />" >> ${tmp_xml_file}
    echo "<language id=\"${language}\" />"          >> ${tmp_xml_file}
    cat ${tmp_file}                                 >> ${tmp_xml_file}
    echo '</body>'                                  >> ${tmp_xml_file}
    echo -n '. '
}

transform_xml() {
    xsltproc -o ${output_dir}/${xml_filename} --novalid ${base_dir}/ep.dtd.xsl ${tmp_xml_file} || exit 1
}

create_required_files() {
    output_xslt
    output_indent
    output_dtd
}

prereqs() {
    xsltproc --dumpextensions | grep -q replace || missing_prereqs
    which xmllint 2>&1 >/dev/null || missing_prereqs
}

missing_prereqs() {
    echo 'This script requires libxslt with the str:replace extension. Try'
    echo " \$ 'xsltproc --dumpextensions | grep replace'"
    echo 'to check if it is installed.'
    echo
    echo 'libxml is also required to check the validity of echo the resultant xml files.'
    exit 1
}

concat_file_fragments() {
    files=
    for f in ep-[0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9]-[0-9][0-9].txt ; do
        base=$(echo ${f//.txt/} | cut -f 1-5 -d -)
        [[ "${files}" =~ ${base} ]] || files="${files} ${base}"
    done
    for f in ${files} ; do
        if [ -f ${f} ] ; then
            cp -v ${f}.txt ${f}.txt.orig
        fi
        echo "Adding to ${f}.txt from ${f}-*.txt"
        for fragment in ${f}-*.txt ; do
            cat ${fragment} >> ${f}.txt
        done
    done

    files=
    for f in ep-[0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9].txt ; do
        base=$(echo ${f//.txt/} | cut -f 1-4 -d -)
        [[ "${files}" =~ ${base} ]] || files="${files} ${base}"
    done
    for f in ${files} ; do
        truncate -s 0 ${f}.txt
        echo "Creating ${f}.txt from ${f}-*.txt"
        for fragment in ${f}-*.txt ; do
            cat ${fragment} >> ${f}.txt
        done
    done
}

get_all_langs() {
    all_langs=$(ls ${base_dir}/txt)
}

get_langs() {
    if [ -z ${lang} ] ; then
        langs=${all_langs}
    else
        langs=${lang}
    fi
}

get_alt_langs() {
    if [ -z "${alt_langs}" ] ; then
        alt_langs=$(ls ${base_dir}/txt | grep -v ${lang})
    fi
}

preprocess() {
    for lang in ${langs} ; do
        cd txt/${lang}
        echo "Pre-processing language: ${lang}"
        concat_file_fragments
        cd ../..
    done
}

convert_all() {
    for lang in ${langs} ; do
        get_alt_langs
        for file in txt/${lang}/ep-[0-9][0-9]-[0-9][0-9]-[0-9][0-9].txt ; do
            convert_file ${file}
        done
    done
}

convert() {
    prereqs
    create_scratch_dir
    create_required_files
    create_output_dirs
    if [ -z "${file}" ] ; then
        convert_all
    else
        lang=$(basename $(dirname ${file}))
        get_alt_langs
        convert_file ${file}
    fi
    delete_scratch_dir
}

get_base_dir() {
    base_dir=$(readlink -f $(dirname "${0}"))
}

create_output_dirs() {
    for l in $(ls ${base_dir}/txt) ; do
        mkdir -p ${base_dir}/${base_output_dir}/${l}
        if [ ! -f ${base_dir}/${base_output_dir}/${l}/ep.dtd ] ; then
            cp ${base_dir}/ep.dtd ${base_dir}/${base_output_dir}/${l}
        fi
    done
}

parseopts() {
    while getopts "dpcf:l:" opt; do
        case ${opt} in
            d)
                set -ex
                ;;
            l)
                lang=${OPTARG}
                ;;
            p)
                preprocess=1
                ;;
            c)
                convert=1
                ;;
            f)
                file=${OPTARG}
                ;;
            *)
                usage
                ;;
        esac
    done
}

parseopts $@
get_base_dir
get_all_langs
get_langs
if [ "${preprocess}" == "1" ] ; then
    preprocess
elif [ "${convert}" == "1" ] ; then
    convert
else
    usage
fi
