<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:template match="/rss">
<html>
    <head>
        <title><xsl:value-of select="channel/title"/></title>
    </head>
    <body style="margin: 20px;font-family:Arial,Helvetica,Verdana,sans-serif;font-size:12px;">
        <div style="margin-bottom:25px;width:500px;background: #EEEEEE; line-height: 1.45em; font-size: 12px; padding: 12px 125px 12px 25px;color: #666;border: 1px solid #CCC;">
        <p>This is an RSS feed designed to be read by an RSS reader.</p>
        <p><strong><a href="/feeds/">What's an RSS Feed?</a></strong><br/>
        </p>
        </div>

        <p>Items in this feed:</p>
        <ul>
        <xsl:for-each select="channel/item">
            <li>
                <p><strong><xsl:value-of select="title"/></strong></p>
            </li>
        </xsl:for-each>
        <xsl:if test="string-length(channel/item) = 0">
            <li>
                <p><strong>No items are currently in this feed.</strong></p>
            </li>
        </xsl:if>
        </ul>
    </body>
</html>
</xsl:template>
</xsl:stylesheet>