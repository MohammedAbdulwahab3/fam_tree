# Build the server with the Go toolchain, then ship only the binary.
#
# The version here must track the go directive in go.mod; the module requires
# 1.24 and will not compile on anything older.
FROM golang:1.24-alpine AS build

WORKDIR /src

# Module files first, so `go mod download` stays cached across source edits.
COPY go.mod go.sum ./
RUN go mod download

COPY . .

# CGO off makes the binary static, which is what lets the runtime stage be a
# bare alpine with no libc to match.
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/server .

FROM alpine:3.20

# Render's managed Postgres requires TLS, and the pgx driver needs the CA
# bundle to verify it. Without this the server starts and then fails every
# query with "certificate signed by unknown authority".
RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app

COPY --from=build /out/server /app/server

# Render's free plan has no persistent disk: anything written under ./uploads
# is gone on the next deploy. Baking in the files the database already points
# at keeps existing photos loading. Newly uploaded files still vanish until a
# disk is attached — see DEPLOY.md.
COPY seed_uploads/ /app/uploads/

# Documentation only. Render injects PORT and config.Port() reads it.
EXPOSE 8080

CMD ["/app/server"]
