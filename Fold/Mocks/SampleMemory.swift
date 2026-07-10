import Foundation

/// Las 12 entradas de memoria del proyecto de ejemplo.
enum SampleMemory {
    static let entries: [MemoryEntry] = [
        MemoryEntry(
            title: "Autenticación: JWT con SessionManager",
            kind: .spec,
            body: "Toda autenticación pasa por `SessionManager`. El backend emite JWT con expiración 24 h. El refresh token se rota en cada uso.",
            source: "specs/auth/spec.md",
            dateLabel: "2025-09-18 · 14:32",
            linkLabel: "abrir →"
        ),
        MemoryEntry(
            title: "API: versionado en path, no en header",
            kind: .spec,
            body: "Las versiones de la API van en el path (`/v1/...`), nunca en headers. Los breaking changes exigen versión nueva.",
            source: "specs/api/spec.md",
            dateLabel: "2025-10-02 · 09:15",
            linkLabel: "abrir →"
        ),
        MemoryEntry(
            title: "Rate limiting por tier",
            kind: .spec,
            body: "Los límites de petición dependen del tier del usuario (free/premium). Se aplican por middleware, con cabeceras `X-RateLimit-*`.",
            source: "specs/api/rate-limit.md",
            dateLabel: "2025-11-20 · 17:40",
            linkLabel: "abrir →"
        ),
        MemoryEntry(
            title: "Sync: Last-Write-Wins por updatedAt",
            kind: .spec,
            body: "La resolución de conflictos compara `updatedAt`; gana el más reciente. La versión actúa de desempate. El servidor siempre decide.",
            source: "specs/sync/spec.md",
            dateLabel: "2026-01-12 · 11:03",
            linkLabel: "abrir →"
        ),
        MemoryEntry(
            title: "Login con Apple: validación JWKS",
            kind: .spec,
            body: "El identity token de Apple se valida contra su JWKS público, cacheado con TTL 1 h. El `sub` mapea a `apple_sub`.",
            source: "specs/auth/apple.md",
            dateLabel: "2026-05-09 · 14:32",
            linkLabel: "abrir →"
        ),
        MemoryEntry(
            title: "No usar singletons",
            kind: .convention,
            body: "Inyección de dependencias en todos los handlers. Nada de `var Instance = ...` a nivel de paquete excepto config inmutable.",
            source: "CLAUDE.md · code style",
            dateLabel: "2025-08-04 · 11:08",
            linkLabel: "añadido manualmente"
        ),
        MemoryEntry(
            title: "async/await preferido",
            kind: .convention,
            body: "Concurrencia con async/await; los callbacks solo en bordes con APIs legacy. Nada de semáforos para «esperar» trabajo async.",
            source: "CLAUDE.md · code style",
            dateLabel: "2025-08-04 · 11:21",
            linkLabel: "añadido manualmente"
        ),
        MemoryEntry(
            title: "Errores tipados por dominio",
            kind: .convention,
            body: "Cada módulo define su enum de errores. Los handlers traducen a HTTP en el borde; el dominio nunca conoce códigos de estado.",
            source: "CLAUDE.md · code style",
            dateLabel: "2025-09-30 · 16:02",
            linkLabel: "añadido manualmente"
        ),
        MemoryEntry(
            title: "Decisión: Postgres sobre MongoDB",
            kind: .decision,
            body: "El modelo es relacional y las transacciones importan. Postgres con Fluent; FTS5 para búsqueda. Mongo no aporta nada aquí.",
            source: "archive/2025-07-22-storage-decision",
            dateLabel: "2025-07-22 · 10:45",
            linkLabel: "ver change"
        ),
        MemoryEntry(
            title: "Decisión: monolito modular vs microservicios",
            kind: .decision,
            body: "Optamos por monolito modular. El equipo es pequeño y la latencia entre microservicios sería un coste sin contrapartida.",
            source: "archive/2025-09-12-architecture-review",
            dateLabel: "2025-09-12 · 16:47",
            linkLabel: "ver change"
        ),
        MemoryEntry(
            title: "Decisión: cache JWKS en memoria, TTL 1 h",
            kind: .decision,
            body: "Validación local del identity token con el JWKS cacheado. Refresh automático en background ante rotación de claves.",
            source: "archive/2026-05-09-add-apple-login",
            dateLabel: "2026-05-09 · 14:32",
            linkLabel: "ver change"
        ),
        MemoryEntry(
            title: "Lección: tokens JWT sin validar firma",
            kind: .lesson,
            body: "En el primer intento, el agente confió en el `sub` sin validar la firma. Aprendizaje: siempre validar la firma de tokens externos antes de mapear a usuario.",
            source: "archive/2026-05-09-add-apple-login",
            dateLabel: "2026-05-09 · 14:32",
            linkLabel: "ver change"
        ),
    ]
}
