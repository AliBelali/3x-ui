# ========================================================
# Stage: Builder
# ========================================================
FROM golang:1.23-bookworm AS builder
WORKDIR /app
ARG TARGETARCH

RUN apt-get update -y \
  && apt-get install -y \
  build-essential \
  gcc \
  wget \
  unzip

COPY . .

ENV CGO_ENABLED=1
ENV CGO_CFLAGS="-D_LARGEFILE64_SOURCE"
RUN go build -o build/x-ui main.go
RUN ./DockerInit.sh "$TARGETARCH"

# ========================================================
# Stage: Final Image of 3x-ui
# ========================================================
FROM debian
ENV TZ=Asia/Tehran
WORKDIR /usr/local/x-ui

RUN apt-get update -y \
  && apt-get install -y \
  ca-certificates \
  tzdata \
  fail2ban \
  bash \
  openssh-server \
  procps \
  iproute2 \
  systemctl \
  socat \
  tar \
  wget \
  sed \
  iputils-ping \
  certbot

COPY --from=builder /app/build/ /usr/local/x-ui/
COPY --from=builder /app/DockerEntrypoint.sh /usr/local/x-ui/
COPY --from=builder /app/x-ui.sh /usr/bin/x-ui
COPY x-ui.service /etc/systemd/system/
RUN systemctl daemon-reload \
  && systemctl enable x-ui

# Configure ssh-server
RUN sed -i "s/#ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/g" /etc/ssh/sshd_config \
  && sed -i "s/#ListenAddress ::/ListenAddress ::/g" /etc/ssh/sshd_config \
  && sed -i "s/#PermitRootLogin .*$/PermitRootLogin yes/g" /etc/ssh/sshd_config

# Configure fail2ban
RUN rm -f /etc/fail2ban/jail.d/alpine-ssh.conf \
  && cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local \
  && sed -i "s/^\[ssh\]$/&\nenabled = false/" /etc/fail2ban/jail.local \
  && sed -i "s/^\[sshd\]$/&\nenabled = false/" /etc/fail2ban/jail.local \
  && sed -i "s/#allowipv6 = auto/allowipv6 = auto/g" /etc/fail2ban/fail2ban.conf \
  && sed -i '0,/action =/s/backend = auto/backend = systemd/' /etc/fail2ban/jail.conf

RUN echo '[3x-ipl]\n\
enabled=true\n\
filter=3x-ipl\n\
action=3x-ipl\n\
logpath=/var/log/3xipl.log\n\
maxretry=5\n\
findtime=120\n\
bantime=5m'\
>> /etc/fail2ban/jail.d/3x-ipl.conf

RUN echo '[Definition]\n\
datepattern = ^%%Y/%%m/%%d %%H:%%M:%%S\n\
failregex   = \[LIMIT_IP\]\s*Email\s*=\s*<F-USER>.+</F-USER>\s*\|\|\s*SRC\s*=\s*<ADDR>\n\
ignoreregex ='\
>> /etc/fail2ban/filter.d/3x-ipl.conf
  
RUN echo '[INCLUDES]\n\
before = iptables-common.conf\n\
\n\
[Definition]\n\
actionstart = ip route replace unreachable 100.64.0.0\n\
\n\
actionstop = ip route del unreachable 100.64.0.0\n\
\n\
actioncheck = ip route show | grep "unreachable 100.64.0.0"\n\
\n\
actionban = ping -s 72 -c 1 <ip>\n\
            ip route add unreachable <ip>\n\
            echo "$(date +"%%Y/%%m/%%d %%H:%%M:%%S")   BAN   [Email] = <F-USER> [IP] = <ip> banned for <bantime> seconds." >> /var/log/3xipl-banned.log\n\
\n\
actionunban = ip route del unreachable <ip>\n\
              ping -s 82 -c 1 <ip>\n\
              echo "$(date +"%%Y/%%m/%%d %%H:%%M:%%S")   UNBAN   [Email] = <F-USER> [IP] = <ip> unbanned." >> /var/log/3xipl-banned.log\n\
\n\
[Init]'\
>> /etc/fail2ban/action.d/3x-ipl.conf

RUN touch /var/log/3xipl.log
RUN touch /var/log/3xipl-banned.log

RUN chmod +x \
  /usr/local/x-ui/DockerEntrypoint.sh \
  /usr/local/x-ui/x-ui \
  /usr/bin/x-ui \
  /etc/systemd/system/x-ui.service

VOLUME [ "/etc/x-ui" ]
CMD [ "./x-ui" ]
ENTRYPOINT [ "/usr/local/x-ui/DockerEntrypoint.sh" ]
