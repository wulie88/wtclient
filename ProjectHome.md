<p>Here is a simple class that allows you to transfer files via WebDAV.</p>
<h2>Inside it uses:</h2>
<ul>
<li>CFNetwork for HTTP/HTTPS connections.</li>
<li>Streams for reading and writing files.</li>
<li>NSXMLParser for parsing WebDAV responses.</li>
</ul>

<h2>Known Issues and Future plans:</h2>
<ul>
<li>At the moment it doesn't provide anything unrelated to file transferring.</li>
<li>It doesn't support resuming upload/download and timeout handling yet, but I'm working on this.</li>
<li>No documentation yet, and not many comments in the code. However, there is a simple example for the iPhone platform.</li>
</ul>