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
# $ cd europarl/txt/en
# $ ../../../europarl-parser.sh -c -a
#  or
# $ ../../../europarl-parser.sh -c -f ep-2010-07-07.txt
#
# Processed files will end up in europarl/txt/en/processed
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
# http://modnlp.berlios.de/
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

# Uncomment the following line to debug
#set -x

# Some user variables
REMOVE_TMP_FILES=0 # set to 1 to remove temporary files, 0 otherwise
INDENT=1           # set to 1 to indent the xml files, 0 otherwise
SKIP_EXISTING=0    # set to 1 to skip files that have already been processed
RENAME_FILES=1     # set to 1 to rename files to e.g. EN20031222.xml
# each language directory needs to be validated
# against a separate language, because all the native language interventions
# will be marked as UNKNOWN. E.g. in the 'en' directory, all interventions
# that should be marked LANGUAGE="EN" are in fact marked LANAGUAGE="UNKNOWN"
# So we validate these against another language directory where they are
# correctly attributed. Either set this here and run the preprocesser against
# those language directories. If not set, it will scan all other-language
# directories for the correct files.
alt_langs=""

# Optional variables
output_dir=./processed
xsl_file=ep.dtd.xsl
indent_file=indent.xsl
tmp_dir=/tmp

usage() {
    echo
    echo "This script converts Europarl Parallel Corpus txt files to ep.dtd-compliant xml"
    echo "See comments in script for futher information."
    echo
    echo "Usage:"
    echo "$0 -c -f FILE (converts a single file to ecpc_EP xml)"
    echo "$0 -c -a          (converts all files in current directory)"
    echo
    echo "This script should be run in the language directory of the corpus."
    echo "e.g. europarl/txt/en for english."
    echo
    exit 0
}

create_tmp_dir() {

    scratch_dir=`mktemp -d -t -p ${tmp_dir}`
    if [ "$?" != "0" ] ; then
        echo "Problem creating temporary directory, is mktemp installed?"
        usage
    fi
}

rm_tmp_dir() {

    if [ "REMOVE_TMP_FILES" == "1" ] ; then
        rm -fr ${scratch_dir}
    fi
}

output_dtd() {

    if [ ! -e ${output_dir}/ep.dtd ] ; then
        cat > ${output_dir}/ep.dtd << EOF
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

    if [ ! -e ${xsl_file} ] ; then
        cat > ${xsl_file} << EOF
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

    if [ ! -e ${indent_file} ] ; then
        cat > ${indent_file} << EOF
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

    for lang in ${alt_langs} ; do
        alt_lang_file=""
        if [ -f ../${lang}/${i} ] ; then
            alt_lang_file=../${lang}/${i}
        else
            continue
        fi
        cp ${alt_lang_file} ${tmp_file}.altlang
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
        new_lang=`grep "${first_segment}" ${tmp_file}.altlang | cut -f4 -d\"`
        rm ${tmp_file}.altlang
        if [ "${new_lang}" != "" ] ; then
            if [ "${new_lang}" == "UNKNOWN" ] || [ "${new_lang}" == "CA" ] || [ "${new_lang}" == "UN" ] ; then
                new_lang=""
            else
                break
            fi
        fi
    done
}

missing_languages() {

    OLDIFS=$IFS
    IFS="
"
    sed -i -e 's/\(SPEAKER ID[^ ]*\)\( NAME=[^>]*>\)/\1 LANGUAGE=\"\"\2/g' ${tmp_file}
    for speaker_segment in `grep "SPEAKER ID" ${tmp_file}` ; do
        new_lang=""
        old_lang=`echo "${speaker_segment}" | cut -f4 -d\"`
        first_segment=`echo "${speaker_segment}" | cut -f1-3 -d\"`
        if [ "${old_lang}" == "" ] ; then
            find_new_lang
            if [ "${new_lang}" != "" ] ; then
                second_segment=`echo $speaker_segment | sed -e 's/\\//\\\\\//g' -e 's/\\*//g' -e 's/\\[/\\\\[/g' \
                                                -e 's/\\]/\\\\]/g'  | cut -f5- -d\"`
                sed -i -e "s/\(${first_segment}\"\).*\(\"${second_segment}\)/\1${new_lang}\2/" ${tmp_file}
            fi
        fi
    done

    IFS=$OLDIFS

}

convert_all() {

    for j in *.txt ; do
        i=${j}
        convert_file
    done
}

get_new_filename() {

    let year=10#`echo ${base_filename} | cut -f 2 -d -`
    if [ ${year} -gt 95 ] ; then
        year=19${year}
    else
        if [ ${year} -lt 10 ] ; then
            year=200${year}
        else
            year=20${year}
        fi
    fi
    month=`echo ${base_filename} | cut -f 3 -d -`
    day=`echo ${base_filename} | cut -f 4 -d -`
    base_xml_filename=${language}${year}${month}${day}
    xml_filename=${base_xml_filename}.xml
}

not_valid() {

    echo ". not valid, moving to ${xml_filename}.bad"
    mv ${output_dir}/${xml_filename} ${output_dir}/${xml_filename}.bad
}

is_valid() {

    echo -n ". (valid)"
    if [ "$INDENT" == "1" ] ; then
        xsltproc -o ${output_dir}/${xml_filename} ${scratch_dir}/${indent_file} ${output_dir}/${xml_filename} && echo " (indented)"
    fi
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
    -e 's/LANGUAGE="CA"//g' \
    -e 's/LANGUAGE="EM"//g' ${tmp_file}
}

convert_file() {

    echo -n "Processing ${i} . "

    if [ ! -f ${i} ] ; then
        echo "(${i} does not exist)"
        return
    fi

    base_filename=`basename ${i} .txt`
    xml_tmp_file=${scratch_dir}/${base_filename}.tmp.xml

    if [ "${xml_filename}" == "" ] ; then
        let length=$(echo ${i} | wc -c)
        if [ ${length} -ne 16 ] ; then
            return
        fi
    fi

    base_xml_filename=${base_filename}
    tmp_file=${scratch_dir}/${base_filename}.tmp
    pwd=`pwd`
    language=`basename ${pwd} | tr a-z A-Z`

    if [ "$RENAME_FILES" == "1" ] ; then
        if [ "${xml_filename}" == "" ] ; then
            get_new_filename
        fi
    else
        xml_filename=${base_filename}.xml
    fi

    if [ "$SKIP_EXISTING" == "1" ] && [ -f ${output_dir}/${xml_filename} ] ; then
        echo "output file exists, skipping."
        xml_filename=""
        return
    fi

    cp ${i} ${tmp_file}

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
    sed -i -e 's/&/and/g' \
                 -e 's/?ratsa-?sagaropoulou/Kratsa-Tsagaropoulou/g' \
                 -e 's/S<nchez/Sánchez/g'       \
                 -e 's/PPE[–|_]DE/PPE-DE/g' \
                 -e 's/()//g'       \
                 -e 's/<0}*//g' \
                 -e 's/{0>//g'  \
                 -e 's/ \.//g' \
                 -e 's/ –//g' \
                 -e 's/ / /g' \
                 -e 's/<-//g' ${tmp_file}

    # remove paragraphs, empty speaker elements, chapter elements
    # add quotes to non-quoted ID tags
    # FIXME: there are still empty speaker elements after this.
    sed -i -e 's/<SPEAKER.*\/>//g' \
                 -e 's/<\/*P.*>//g' \
                 -e '/<CHAPTER/{ :f; s/<CHAPTER.*\(<SPEAKER\)/\1/; t; N; bf; }' ${tmp_file}
    sed -i '1i\
' ${tmp_file}

    perl -pi -e 'print "\n" if $. == 1; undef $/; s{(<(\w+).*?>.*?)(?=\s*(<\w|\z))}{$1."\n</$2>"}esg' ${tmp_file}

    # remove extra quotes in name element
    sed -i -e 's/\(NAME=".*\)"\(.*\)"\(.*"\)/\1\2\3/g' \
                 -e 's/\(NAME=".*\)"\(.*\)"\(.*"\)/\1\2\3/g' \
                 -e 's/\(NAME=\".*\)"\(.*\"\)/\1\2/g'                \
                 -e "s/\(NAME=\".*\)'\(.*\"\)/\1\2/g" ${tmp_file}

    sed -i -e 's/\(NAME="[^"]*\) AFFILIATION=\([^"]*\)">/\1" AFFILIATION="\2">/g' ${tmp_file}

    echo "<body>" > ${xml_tmp_file}
    echo "<filename id=\"${base_xml_filename}\" />" >> ${xml_tmp_file}
    echo "<language id=\"${language}\" />" >> ${xml_tmp_file}
    cat ${tmp_file} >> ${xml_tmp_file}
    echo "</body>" >> ${xml_tmp_file}
    echo -n ". "

    xsltproc -o  ${output_dir}/${xml_filename} --novalid ${scratch_dir}/${xsl_file} ${xml_tmp_file} || exit 1
    # this removes any EPparty attributes that don't match the DTD
    # if you change the DTD above or elsewhere, change it here too
    sed -i -e 's/ EPparty="\(PPE-DE\|PSE\|ALDE\|Verts-ALE\|GUE-NGL\|IND-DEM\|UEN\|NI\|ELDR\|EDD\|EPP-DE\|PPE\|UPE\|TDI\|EFD\|ITS\|ECR\|S-D\|UNKNOWN\)"/@="\1"/g
                         s/  *EPparty="[^"]*"//g
                         s/@="/ EPparty="/g' ${output_dir}/${xml_filename}

    # remove this for now. in future, sometimes the affiliation
    # contains the post.
#  sed -i -e 's/\(<name>.*\)AFFILIATION=.*\(<\/name>\)/\1\2/g' ${output_dir}/${xml_filename}

    xmllint --noout --valid ${output_dir}/${xml_filename} && is_valid || not_valid

    if [ "$REMOVE_TMP_FILES" ==  "1" ] ; then
        rm ${tmp_file}
        rm ${xml_tmp_file}
    fi

    xml_filename=""

}

create_tmp_files() {

    if [ ! -e ${output_dir} ] ; then
        mkdir -p ${output_dir}
    fi
    pushd ${scratch_dir} > /dev/null
    output_xslt
    output_indent
    popd > /dev/null
    output_dtd
}

rm_tmp_files() {

    if [ "$REMOVE_TMP_FILES" ==  "1" ] ; then
        pushd ${scratch_dir} > /dev/null
        rm $xsl_file
        rm $indent_file
        popd > /dev/null
    fi
}

find_alt_langs() {

    if [ "${alt_langs}" == "" ] ; then
    # assume we are in the $current_lang directory
        current=`basename ${PWD}`
        alt_langs=`ls .. | grep -v ${current}`
    fi

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

concat_file_parts() {

    files=""
    for i in    *.txt ; do
        let length=$(echo ${i} | wc -c)
        if [ $length -gt 16 ] ; then
            base=$(basename ${i} .txt | cut -f 1-4 -d -)
            echo ${files} | grep ${base} 2>&1 >/dev/null
            if [ $? -ne 0 ] ; then
                files="${files} ${base}"
            fi
        fi
    done

    for i in ${files} ; do
        rm -f ${i}.txt
        for j in ${i}*.txt ; do
            cat ${j} >>${i}.txt
        done
    done

}

preprocess() {

    find_alt_langs
    concat_file_parts
    for lang in ${alt_langs} ; do
        cd ../${lang}
        concat_file_parts
    done
    cd ../${current}

}


convert() {
    prereqs
    create_tmp_dir
    create_tmp_files
    find_alt_langs
    if [ "${parse_all}" == "1" ] ; then
        convert_all
    elif [ "${convert_files}" == "1" ] ; then
        i=${infile}
        convert_file
    else
        echo "Error: no files specified for converstion."
        usage
    fi
    rm_tmp_files
    rm_tmp_dir

}

parseopts() {
    while getopts "dapcf:o:" opt; do
        case ${opt} in
            d)
                set -ex
                ;;
            a)
                parse_all=1
                ;;
            c)
                convert_files=1
                ;;
            f)
                infile=$OPTARG
                ;;
            o)
                xml_filename=$OPTARG
                ;;
            *)
                usage
                ;;
        esac
    done
}

parseopts $@

#parse_all=1
#convert_files=1
#infile=$1

prereqs
if [ "${convert_files}" == "1" ] ; then
    convert
else
    usage
fi
