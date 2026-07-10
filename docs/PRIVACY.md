# Política de privacidad — Fold

Fold es **local-first**:

- No envía telemetría, analíticas ni crash reports a ningún servidor.
- No abre conexiones de red propias. La única red que se usa es la de las
  CLIs de agente que TÚ ejecutas, con tus cuentas y tus condiciones.
- Tus specs, changes, memoria e historial viven como archivos planos en tus
  repos. Fold no guarda copia fuera de ellos (solo la lista de proyectos
  recientes, en `~/Library/Application Support/Fold/`).
- Fold no registra prompts completos, tokens de acceso ni variables de
  entorno sensibles; el entorno de los agentes se sanea antes de ejecutar.
- El export de diagnóstico es opcional, se genera bajo demanda y contiene
  versiones y estados de la app — nunca credenciales ni contenido del repo.

Si algún día se plantea telemetría, será opt-in explícito, documentado y con
el detalle exacto de lo que se envía. Hasta entonces: nada sale de tu máquina.
