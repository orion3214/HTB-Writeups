<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
           <xsl:output method="html"/>
           <xsl:template match="/">
                   <h2>Detecting the underlying XSLT engine ...</h2>
                   <b>Version:</b> <xsl:value-of select="system-property('xsl:version')" /><br/>
                   <b>Vendor:</b> <xsl:value-of select="system-property('xsl:vendor')" /><br/>
                   <b>Vendor URL:</b> <xsl:value-of select="system-property('xsl:vendor-url')" /><br/>
           </xsl:template>
 </xsl:stylesheet>
