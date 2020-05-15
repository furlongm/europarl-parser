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
