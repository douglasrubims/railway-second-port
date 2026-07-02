FROM caddy:latest

EXPOSE 3000

WORKDIR /app

COPY Caddyfile ./

COPY --chmod=755 entrypoint.sh ./

RUN caddy fmt --overwrite Caddyfile

ENTRYPOINT ["/bin/sh"]

CMD ["entrypoint.sh"]
