# Squid Proxy with FRP Tunneling

This project sets up a Squid proxy that runs behind a NAT or firewall, exposing it to the internet using `frp` (a fast reverse proxy). This allows you to route your traffic through the proxy server without exposing it directly.

## How It Works

The setup involves three main components:

*   **Client**: Your local machine or browser that wants to send traffic through the proxy.
*   **Broker Server (frps)**: A publicly accessible server that acts as a middleman. It accepts connections from the proxy servers and forwards traffic from clients to them.
*   **Proxy Server (squid + frpc)**: A Squid proxy server that can be located anywhere (e.g., behind a NAT). It initiates a connection to the Broker Server and waits for traffic to proxy.

### Architecture

```
                   ┌────────────┐       ┌─ ─ ─ ─ ─ ─ ─ ─ ┐
                   │  BROKER    │   ┌ - ► PROXY SERVER N │
                   │  SERVER    │       │ IP ..........  │
                   │ IP 5.6.7.8 │   │   └────────────────┘
                   │            │       ┌────────────────┐     ┌───────────────────┐
                   │            │   ┌───┼ PROXY SERVER 1 ┼─────► https://ipinfo.io │
  ┌────────────┐   │            │   │   │ IP 11.11.11.11 │     └───────────────────┘
  │   CLIENT   │   │            │   │   └────────────────┘
  │ IP 1.2.3.4 │───►:17001      │   │   ┌────────────────┐
  └────────────┘   │:17002 :7000◄───┼───┼ PROXY SERVER 2 │
                   │:17003      │   │   │ IP 12.12.12.12 │
                   │:.....      │   │   └────────────────┘
                   │:1700n      │   │   ┌────────────────┐
                   │            │   └───┼ PROXY SERVER 3 │
                   │            │       │ IP 13.13.13.13 │
                   └────────────┘       └────────────────┘
```

Without the proxy, your IP is exposed:
```sh
curl https://ipinfo.io
# Output: {"ip": "1.2.3.4", ...}
```

With the proxy, the IP of the proxy server is used:
```sh
curl -x http://user:pass@5.6.7.8:17001 https://ipinfo.io
# Output: {"ip": "11.11.11.11", ...}
```

---

## Deployment

Follow these steps to deploy the broker and proxy servers.

### 1. Run the Broker Server (frps)

The broker server requires a public IP and several open ports:
*   **`7000` (TCP)**: For proxy clients (`frpc`) to connect.
*   **`17000` (HTTP)**: For the `frps` dashboard.
*   **`17001-17999` (TCP)**: For your clients to connect to the proxies.

**Configuration (`frps.toml`)**
```toml
# ./frps.toml
[common]
bind_port = 7000
token = "{{ .Envs.FRP_TOKEN }}"

# Dashboard configuration
dashboard_port = 17000
dashboard_user = "admin"
dashboard_pwd = "another_secure_password"

# Logging
log_file = "./frps.log"
log_level = "info"
log_max_days = 7
```

**Run with Docker:**
```sh
docker run -d --name frps --network host \
  -v $(pwd)/frps.toml:/frps.toml \
  -e FRP_TOKEN=a_secure_password_123 \
  ghcr.io/fatedier/frps:v0.65.0 /usr/bin/frps -c /frps.toml
```

**Run with Docker:**
```yaml
services:
  frps:
    image: ghcr.io/fatedier/frps:v0.65.0
    volumes:
      - ./frps/frps.toml:/frps.toml
    container_name: frps
    ports:
      - "7000:7000"
      - "17000:17000"
    network_mode: "host"
    restart: unless-stopped
	environment:
      - FRP_TOKEN=a_secure_password_123
    entrypoint: ["/usr/bin/frps", "-c", "/frps.toml"]
```

Once running, you can access the dashboard at `http://<broker-server-ip>:17000`.

### 2. Run the Proxy Server (squid + frpc)

Run this on any machine you want to use as a proxy.

**Run with Docker Compose (`docker-compose.yml`):**
```yaml
services:
  squid-proxy:
    image: ghcr.io/thanhpk/squid:main
    container_name: squid-proxy
    restart: unless-stopped
    environment:
      - SQUID_USER=user1
      - SQUID_PASS=s3cret
      - FRP_SERVER_ADDR=frp.subiz.net # Replace with your broker IP
      - FRP_TOKEN=a_secure_password_123 # Must match broker server
      - FRP_REMOTE_PORT=17001 # must be unique for each proxy server
      - TZ=UTC
```
**Run with Docker:**
```sh
docker run -d --name squid-proxy \
  -e SQUID_USER=user1 \
  -e SQUID_PASS=s3cret \
  -e FRP_SERVER_ADDR=frp.subiz.net \
  -e FRP_TOKEN=a_secure_password_123 \
  -e FRP_REMOTE_PORT=17001 \
  -e TZ=UTC \
  --restart unless-stopped \
  ghcr.io/thanhpk/squid:main
```

#### Environment Variables

| Variable          | Description                                                    |
|-------------------|----------------------------------------------------------------|
| `SQUID_USER`      | The username for authenticating with the Squid proxy.          |
| `SQUID_PASS`      | The password for authenticating with the Squid proxy.          |
| `FRP_SERVER_ADDR` | The address of the broker server (`frps`).                     |
| `FRP_TOKEN`       | The authentication token to connect to the broker.             |
| `FRP_REMOTE_PORT` | The port on the broker to expose this Squid proxy on.          |
| `TZ`              | Sets the timezone for the container (e.g., `UTC`).             |


---

## How to Use

On your local machine, check your current public IP:
```sh
curl https://ipinfo.io/ip
```

Now, make a request through the proxy. The URL is constructed using the credentials for the **Squid proxy** and the address of the **broker server**.
```sh
curl -x http://user1:s3cret@<broker-server-ip>:<frp-remote-port> https://ipinfo.io/ip
```
Example:
```sh
curl -x http://user1:s3cret@5.6.7.8:17001 https://ipinfo.io/ip
```

This should return the IP of one of your proxy servers, not your local IP.

---

## Development

1.  Ask a team member for the development `FRP_TOKEN`.
2.  Add it to your shell profile (`.zshrc`, `.bashrc`, etc.):
    ```sh
    export FRP_TOKEN="..."
    ```
3.  Reload your shell or open a new terminal and run the debug script:
    ```sh
    ./debug.sh
    ```
4.  In another terminal, test the connection:
    ```sh
    curl -x http://user1:s3cret@frp.subiz.net:17002 https://api5.subiz.com.vn/4.1/ip
    ```
This command routes traffic from your machine to the `frp.subiz.net` broker, which forwards it back to the Squid instance running locally via the FRP tunnel, which then makes the final request to `api.subiz.com.vn`.

---
This repository is based on the official [Ubuntu Squid Docker image](https://git.launchpad.net/~ubuntu-docker-images/ubuntu-docker-images/+git/squid/).
