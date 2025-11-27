## important Rules

- 1. Fundamentos de Trabajo

    📖 Lee siempre los archivos completos
    Para evitar malentendidos de arquitectura, duplicar código o cometer errores.

    💾 Haz commits temprano y con frecuencia
    Divide tareas grandes en hitos lógicos. Confirma cada hito y haz commit antes de continuar.

    🔍 Verifica documentación actualizada de librerías
    Tu conocimiento interno podría estar desactualizado.

    Usa Perplexity primero.

    Usa búsqueda web solo si Perplexity no está disponible.

    🚫 No descartes librerías por fallos iniciales
    Si algo “no funciona”, probablemente estás usando sintaxis o patrones incorrectos.

- 2. Buenas Prácticas de Código

    🧹 Ejecuta linting después de cambios importantes
    Detecta errores de sintaxis, métodos incorrectos o mal uso de funciones.

    📂 Organiza el código en archivos separados
    Usa buenas prácticas:

    Nombres de variables claros.

    Funciones modulares y simples.

    Archivos con tamaño razonable y comentarios relevantes.

    👀 Optimiza para la lectura, no solo para la escritura
    El código se lee más veces de lo que se escribe.

    ⚡ Implementa de verdad, sin "dummy code"
    Si el usuario pide algo, hazlo funcional. No muestres “cómo se vería” sin implementarlo.

- 3. Planificación y Claridad

    ❓ Aclara tareas antes de comenzar
    Haz preguntas si hay ambigüedad. No asumas.

    🛑 Evita refactors grandes sin autorización
    Solo haz cambios estructurales si el usuario lo pide explícitamente.

    🗺️ Antes de escribir código, crea un Plan

    Entiende la arquitectura actual.

    Identifica los archivos a modificar.

    Considera aspectos arquitectónicos y casos límite.

    Presenta el Plan al usuario para aprobación.

    🔎 Busca la causa raíz de los problemas
    No pruebes cosas al azar ni cambies de librería sin razón.

- 4. Rol y Experiencia Esperada

    🌟 Actúa como un desarrollador senior poliglota
    Con experiencia en arquitectura, diseño de sistemas, desarrollo, UI/UX, redacción técnica y más.

    🎨 En UI/UX, cuida la estética y la usabilidad
    Diseños:

    Atractivos y fáciles de usar.

    Con buenas microinteracciones.

    Basados en patrones y mejores prácticas de UX.

- 5. Manejo de Tareas Grandes o Vagas

-✂️ Divide tareas grandes en subtareas manejables
    Reduce riesgos y facilita revisiones.

- 🗣️ Si es difícil dividirlas, pide ayuda al usuario
    Guía al usuario para segmentar el trabajo y evitar bloqueos o pérdida de tiempo.

- 📡 Flujo de comunicación:


## 🧼 Buenas prácticas

- ✅ Escribir código limpio y modular
- ✅ Usar nombres de variables y funciones en inglés
- ✅ Mantener separación de responsabilidades clara
- ✅ No duplicar lógica entre frontend y backend
- ✅ No mezclar UI con lógica de negocio
- ✅ mantener siempre el proyecto limpio y en order divido en carpetas segun su naturaleza
- ✅ utilizar siempre nuestros entornos docker para simular siempre el entorno de produccion

## Documentacion permitida
- ✅ odoo/LICENSE
- ✅ odoo/README.md



## 🚫 Cosas que deben evitarse

- ❌ Usar ORMs solo si es necesario
- ❌ Acceder directamente a Supabase desde frontend (excepto suscripciones)
- ❌ Crear carpetas nuevas fuera del estándar sin razón
- ❌ no crear componentes, si ya tienes un componente con el nombre y funcion ya sea desatualizada o con errores solo has fix o adaptala a la necesidad requerida sin tener que crear mas archvios con nombres similares ni contenido similar 
- ❌ no crear .md innecesarios 


- 6. Siempre responde en el lenguaje nativo del programador o desarrollador