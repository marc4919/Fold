import Foundation

/// Contenidos markdown largos del change de ejemplo.
enum SampleMarkdown {
    static let proposal = """
    # Login con Apple

    ## ¿Qué?
    Añadir Sign in with Apple como método de autenticación adicional, \
    integrado con el modelo de sesión existente.

    ## ¿Por qué?
    - App Store Review requiere SIWA si hay login social
    - Reduce fricción de signup
    - OAuth2/OIDC estándar

    ## Alcance
    La sesión se maneja con `SessionManager`. Validación del identity token contra JWKS de Apple.

    ## Fuera de alcance
    - Google OAuth (sprint posterior)
    - Sign in with Apple para web
    """

    static let design = """
    # Diseño · Login con Apple

    ## Decisión 1: validación JWKS sobre Apple Auth Server
    Validamos contra el JWKS público de Apple, no contra el endpoint de Apple Auth Server.
    - Latencia: < 1 ms local vs ~200 ms a Apple
    - Quota: evitamos los rate limits de Apple
    - Estándar: OAuth2/OIDC puro

    ## Decisión 2: cache del JWKS
    Memory cache con TTL de 1 h + refresh automático en background.

    ## Decisión 3: mapeo sub → usuario
    El campo `sub` mapea a un campo nuevo `apple_sub` en la tabla users.

    ## Riesgos
    - `sub` estable por app, no por Team ID
    - Rotación del JWKS: necesita refresh automático
    """

    static let tasks = """
    # Tareas

    ## 1. Backend
    - [ ] 1.1 Configurar `apple-services` en config y env
    - [ ] 1.2 Endpoint `POST /auth/apple` con validación JWKS
    - [ ] 1.3 Mapear `sub` a usuario existente o crear nuevo

    ## 2. Calidad
    - [ ] 2.1 Tests de integración con tokens válidos e inválidos
    - [ ] 2.2 Actualizar OpenAPI spec con el nuevo endpoint
    """

    static let deltas = """
    # Deltas de specs

    ## specs/auth/spec.md · MOD
    Se añade Apple como método de login soportado (+1 método).

    ## specs/auth/apple.md · NEW
    Capacidad nueva: requisitos del identity token, validación JWKS, \
    mapeo `sub` → `apple_sub`, expiración y rotación de claves.
    """

    static let briefing = """
    # Sign in with Apple
    exploración técnica · acme-api · 3 approaches comparados

    El objetivo es añadir SIWA **sin tocar el modelo de sesión actual**. \
    Toda autenticación pasa por `SessionManager` y eso no cambia.

    ## Flujo propuesto
    ```
    app iOS → identity token → POST /auth/apple
        → validar firma contra JWKS de Apple (cacheado)
        → mapear sub → usuario → JWT de sesión propio
    ```

    ## Comparación de approaches
    | Approach | Ventaja | Coste | Veredicto |
    | 1 · Apple Auth Server | simple | latencia ~200 ms + quota | descartado |
    | 2 · JWKS local | < 1 ms, estándar | cache + rotación | recomendado |
    | 3 · SDK de terceros | rápido de montar | dependencia opaca | descartado |

    ## Riesgos detectados
    | Riesgo | Impacto | Mitigación |
    | sub por app, no por Team ID | cuentas duplicadas | documentar + apple_sub |
    | rotación JWKS | logins fallidos | refresh automático en background |

    > **Decisión:** approach 2 (JWKS). El modelo de sesión no cambia.
    """

    static let frugalBriefingPoints: [String] = [
        "Auth actual: JWT emitido por SessionManager; SIWA no lo cambia.",
        "Approach recomendado: validar identity token contra JWKS de Apple, cacheado TTL 1 h.",
        "Riesgo: el sub es estable por app, no por Team ID — mapear a apple_sub.",
        "Tres approaches comparados; el 2 gana por latencia y estándar.",
    ]

    static let idea = """
    Añadir Sign in with Apple a la app iOS, integrándolo con SessionManager. \
    Validar el identity token contra el JWKS de Apple (cacheado, TTL 1 h). \
    Documentar la limitación de sub por app.
    """
}
