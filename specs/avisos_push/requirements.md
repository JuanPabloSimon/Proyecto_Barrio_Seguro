# Requirements — avisos_push

> Feature #12 de `feature_list.json`: Avisos con la app cerrada (Firebase Cloud Messaging).
>
> Cada requisito está en EARS estricto (ver `docs/specs.md`) y se verifica
> con al menos una prueba concreta.

## R1
CUANDO el vecino activa los avisos en su perfil o abre la app con una sesión activa y los avisos habilitados, el sistema DEBE suscribir el dispositivo al canal de avisos push de alertas del barrio.

## R2
CUANDO el vecino desactiva los avisos en su perfil o cierra su sesión, el sistema DEBE cancelar la suscripción del dispositivo al canal de avisos push de alertas del barrio.

## R3
CUANDO un vecino crea una alerta activa en el servidor, el sistema DEBE enviar un aviso push con los datos de la alerta al canal del barrio.

## R4
CUANDO el dispositivo recibe un aviso push de una alerta activa reportada por otro vecino mientras la app está cerrada o en segundo plano, el sistema DEBE mostrar una notificación del sistema con el título y la dirección de la alerta.

## R5
CUANDO el vecino toca la notificación generada por un aviso push, el sistema DEBE abrir la pantalla de detalle de esa alerta.

## R6
SI el aviso push recibido corresponde a una alerta reportada por el mismo vecino que tiene la sesión abierta en el dispositivo ENTONCES el sistema DEBE descartar el aviso sin mostrar ninguna notificación.

## R7
SI una alerta ya tiene estado resuelta al momento de enviar o procesar el aviso push ENTONCES el sistema DEBE descartar el aviso sin enviarlo ni mostrar ninguna notificación.

## R8
SI el vecino no otorgó el permiso de notificaciones o el servicio de avisos push falla ENTONCES el sistema DEBE continuar funcionando con normalidad sin bloquear el uso de la app ni la creación de alertas.

## Trazabilidad con el `acceptance` de feature_list.json

| Criterio de aceptación | Cubierto por |
|---|---|
| Con la app cerrada, cuando otro vecino crea una alerta, el teléfono muestra una notificación | R1, R3, R4 |
| Tocar la notificación abre el detalle de esa alerta | R5 |
| El vecino que creó la alerta no recibe su propio aviso | R6 |
| Si la alerta ya está resuelta cuando se va a enviar el aviso, no se avisa | R7 |
| Sin el permiso de notificaciones la app sigue funcionando igual que hoy | R2, R8 |
| Pruebas con un servicio de push falso en la app y en el backend | R1, R2, R3, R4, R5, R6, R7, R8 |
