A web service's DMZ infrastructure typically includes a web server, a reverse proxy, a Web Application Firewall (WAF), and potentially a dedicated load balancer, all placed behind a firewall that separates the DMZ from the internal network. This architecture allows public access to the web service while protecting sensitive internal resources, such as databases and internal servers, from direct exposure to the internet. 
Key components and their roles
•	Firewall: 
Acts as the primary security device, controlling traffic between the internet, the DMZ, and the internal network. 
•	Allows inbound traffic to specific ports on the DMZ web server (e.g., port 80 for HTTP, 443 for HTTPS).
•	Strictly controls any outbound traffic initiated from the DMZ to the internal network. 
•	Web Server: 
Hosts the public-facing web application. This server is the direct target for internet-based traffic. 
•	Reverse Proxy: 
Sits in front of the web server and handles incoming requests. It can provide additional security and performance benefits, such as SSL termination and caching. 
•	Web Application Firewall (WAF): 
Analyzes HTTP traffic to protect web servers from attacks like cross-site scripting (XSS) and SQL injection. 
•	Internal Database Server: 
Contains the data for the web application. It is located on the internal network, not the DMZ, to protect it from direct internet access. 
•	Firewall Rules: 
The firewall's policies are crucial for security. It should allow traffic from the internet to the web server in the DMZ but block any direct access from the DMZ to the internal network unless it is explicitly required and secured through a one-way connection or a dedicated application firewall. 
Example traffic flow
1.	A user on the internet sends a request to the web service's IP address.
2.	The firewall receives the request and, based on its rules, forwards it to the reverse proxy/load balancer in the DMZ.
3.	The reverse proxy may handle the request directly (e.g., if content is cached) or pass it to the WAF.
4.	The WAF inspects the request for malicious activity and, if clean, passes it to the web server. 
5.	The web server processes the request, which may involve retrieving or storing data from the internal database. This communication is strictly controlled by the firewall, often involving a specific, one-way rule. 
6.	The web server sends the response back through the reverse proxy, WAF, and firewall to the user on the internet. 

