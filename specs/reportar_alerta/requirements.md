# Requirements — reportar_alerta

> Feature #18 de `feature_list.json`: Reportar alertas desde el inicio.
>
> Cada requisito está en EARS estricto (ver `docs/specs.md`) y se verifica
> con al menos una prueba concreta.
>
> Decisiones ya tomadas por el equipo y que este spec da por fijas:
>
> - Botón "Reportar alerta" en el inicio, debajo del mapa y arriba de
>   "Llamar al 911", del mismo ancho que el mapa; "Llamar al 911" pasa a
>   tener ese mismo ancho.
> - El formulario pide tipo (Actividad sospechosa, Vehículo sospechoso,
>   Robo o Ruidos), un título que el vecino puede ajustar, descripción y
>   ubicación (GPS como el SOS o zona del barrio, más un campo para la
>   dirección).
> - Al enviar queda Activa y aparece en la lista y el mapa; si falla, el
>   formulario lo dice y no se pierde lo escrito.
> - Quitar Arrebato reusa el análisis de `progress/spec_quitar_arrebato.md`
>   (verificado contra el código actual, ver `design.md`): el valor
>   `arrebato` queda en el enum solo para leer, la API responde 400 "Elegí
>   qué tipo de alerta es.", el informe y el aviso tardío no cambian, y la
>   alerta de ejemplo `a4` pasa a ser un robo.
>
> - En la aprobación, el equipo pidió que el botón SOS sea "un poco más
>   grande que hoy, pero no tanto", para que se siga destacando al lado de
>   los dos botones de ancho completo (52 dp de alto). Pasa de 184 x 88 dp
>   con texto de 30 a **216 x 104 dp con texto de 32** (R51 a R53, decisión
>   7 de `design.md`).
>
> Lo que este spec resuelve (ver `design.md`): el formulario es una
> pantalla completa con forma de diálogo (no una hoja inferior), los largos
> máximos y qué campos son obligatorios (iguales en la app y el backend), la
> confirmación al cerrar con datos escritos y cómo se lee "el SOS es el
> botón más grande" con dos botones de ancho completo: por alto (R4) y con
> el SOS agrandado (R51).
>
> "Formulario" es `ReportarAlertaScreen`. "Tipos para reportar" son
> `CategoriaAlerta.paraReportar`. Los nombres visibles de los tipos son
> los de `nombreCorto` (feature 16).

## El inicio

## R1
MIENTRAS se muestra el inicio con las alertas cargadas, el sistema DEBE
mostrar un botón "Reportar alerta" debajo de la tarjeta del mapa y arriba
del botón "Llamar al 911".

## R2
MIENTRAS se muestra el inicio con las alertas cargadas, el sistema DEBE
mostrar el botón "Reportar alerta" con el mismo ancho que la tarjeta del
mapa.

## R3
MIENTRAS se muestra el inicio con las alertas cargadas, el sistema DEBE
mostrar el botón "Llamar al 911" con el mismo ancho que la tarjeta del
mapa.

## R4
MIENTRAS se muestra el inicio con las alertas cargadas, el sistema DEBE
mostrar los botones "Reportar alerta" y "Llamar al 911" con un alto menor
que el del botón SOS (el tamaño del SOS está en R51).

## R5
CUANDO el vecino toca "Reportar alerta" en el inicio, el sistema DEBE abrir
el formulario "Reportar alerta" a pantalla completa.

## El formulario

## R6
MIENTRAS se muestra el formulario, el sistema DEBE ofrecer como tipos para
elegir exactamente "Actividad sospechosa", "Vehículo sospechoso", "Robo" y
"Ruidos", en ese orden.

## R7
CUANDO se abre el formulario, el sistema DEBE mostrarlo sin ningún tipo
elegido y con los campos "Título", "Descripción (opcional)" y "Dirección o
referencia (opcional)" vacíos.

## R8
CUANDO el vecino elige un tipo con el título vacío o igual al nombre del
tipo elegido antes, el sistema DEBE completar el título con el nombre del
tipo recién elegido.

## R9
SI el vecino elige otro tipo después de haber cambiado el título sugerido
ENTONCES el sistema DEBE conservar el título que escribió.

## R10
MIENTRAS se muestra el formulario, el sistema DEBE permitir que el vecino
cambie el texto del título.

## Ubicación

## R11
MIENTRAS el dispositivo tiene GPS y el vecino activó "Compartir ubicación
exacta en alertas", el sistema DEBE mostrar en el formulario el texto
"Vamos a mandar tu ubicación exacta."

## R12
MIENTRAS el dispositivo no tiene GPS o el vecino no activó "Compartir
ubicación exacta en alertas", el sistema DEBE mostrar en el formulario el
texto "Vamos a mandar la zona del barrio, no tu ubicación exacta."

## R13
CUANDO el vecino envía el formulario con el GPS disponible, la ubicación
exacta activada y el GPS respondiendo a tiempo, el sistema DEBE crear la
alerta con la posición que dio el GPS.

## R14
SI al enviar el formulario el dispositivo no tiene GPS, el vecino no
activó la ubicación exacta o el GPS no responde a tiempo ENTONCES el
sistema DEBE crear la alerta con la posición del centro del barrio
(`Barrio.centro`).

## R15
CUANDO el vecino envía el formulario con la dirección escrita, el sistema
DEBE mandar como dirección el texto escrito sin espacios al principio ni
al final.

## R16
CUANDO el vecino envía el formulario con la dirección vacía, el sistema
DEBE mandar como dirección "Ubicación exacta del vecino" si va la posición
del GPS o "Barrio Soberanía (zona aproximada)" si va la del centro del
barrio.

## Enviar

## R17
CUANDO el vecino envía el formulario con datos válidos, el sistema DEBE
crear la alerta con la categoría del tipo elegido, el título y la
descripción sin espacios al principio ni al final y el id del vecino con
la sesión abierta como `reportadaPor`.

## R18
CUANDO el vecino envía el formulario con datos válidos y la descripción
vacía, el sistema DEBE crear la alerta con la descripción vacía.

## R19
CUANDO el servidor (la API o el servidor simulado) recibe una alerta nueva
válida, el sistema DEBE guardarla con estado `activa`.

## R20
CUANDO la alerta del formulario se creó, el sistema DEBE cerrar el
formulario y mostrar el aviso "Reportaste la alerta. Ya aparece en la
lista y el mapa."

## R21
CUANDO la alerta del formulario se creó, el sistema DEBE mostrarla en la
lista "Alertas cerca tuyo" del inicio y en el mapa sin que el vecino tenga
que recargar.

## R22
MIENTRAS se envía la alerta, el sistema DEBE mostrar el botón "Enviar
alerta" deshabilitado y con el indicador "Enviando la alerta".

## R23
MIENTRAS se envía la alerta, el sistema NO DEBE cerrar el formulario con
la X, con "Cancelar" ni con el botón Atrás del sistema.

## Validaciones (iguales en la app y el backend)

## R24
SI el vecino envía el formulario sin elegir un tipo ENTONCES el sistema
DEBE mostrar "Elegí qué tipo de alerta es." debajo de los tipos y no
enviar la alerta.

## R25
SI el vecino envía el formulario con el título vacío o solo con espacios
ENTONCES el sistema DEBE mostrar "Escribí un título para la alerta." en el
campo Título y no enviar la alerta.

## R26
SI el vecino envía el formulario con un título de más de 60 letras (sin
contar los espacios de los extremos) ENTONCES el sistema DEBE mostrar
"Acortá el título: puede tener hasta 60 letras." en el campo Título y no
enviar la alerta.

## R27
SI el vecino envía el formulario con una descripción de más de 500 letras
ENTONCES el sistema DEBE mostrar "Acortá la descripción: puede tener hasta
500 letras." en el campo Descripción y no enviar la alerta.

## R28
SI el vecino envía el formulario con una dirección de más de 120 letras
ENTONCES el sistema DEBE mostrar "Acortá la dirección: puede tener hasta
120 letras." en el campo Dirección y no enviar la alerta.

## R29
SI el vecino envía el formulario con algún dato inválido ENTONCES el
sistema DEBE llevar el foco al primer elemento con error, en el orden
tipos, Título, Descripción, Dirección.

## R30
SI `POST /alertas` recibe un título vacío, un título de más de 60 letras,
una descripción de más de 500 letras o una dirección de más de 120 letras
ENTONCES el sistema DEBE responder 400 con `{"error": ...}` y el mismo
mensaje que muestra la app para ese caso (R25 a R28).

## R31
SI el servidor simulado recibe una alerta nueva con una categoría que no
se acepta, un título vacío o un dato más largo que el máximo ENTONCES el
sistema DEBE rechazarla con `ErrorDelServidor` y el mismo mensaje que la
API.

## Si el envío falla

## R32
SI la API o el servidor simulado rechaza la alerta con un mensaje
(`ErrorDelServidor`) ENTONCES el sistema DEBE mostrar ese mensaje tal cual
en el formulario.

## R33
SI el envío de la alerta falla por la red ENTONCES el sistema DEBE mostrar
en el formulario "No pudimos enviar la alerta. Revisá tu conexión y probá
de nuevo."

## R34
SI el envío de la alerta falla ENTONCES el sistema DEBE dejar en el
formulario el tipo elegido, el título, la descripción y la dirección que
había escritos.

## R35
SI se corta la conexión con el formulario abierto ENTONCES el sistema DEBE
mostrar el formulario con el tipo y los textos escritos cuando vuelve la
conexión.

## Cerrar el formulario

## R36
CUANDO el vecino cierra el formulario (con la X, con "Cancelar" o con el
botón Atrás) sin tipo elegido y sin texto escrito, el sistema DEBE cerrarlo
sin preguntar.

## R37
CUANDO el vecino cierra el formulario (con la X, con "Cancelar" o con el
botón Atrás) con un tipo elegido o algún texto escrito, el sistema DEBE
mostrar el diálogo "¿Descartar la alerta?".

## R38
CUANDO el vecino toca "Sí, descartar" en el diálogo "¿Descartar la
alerta?", el sistema DEBE cerrar el formulario sin crear ninguna alerta.

## R39
CUANDO el vecino toca "Seguir escribiendo", el botón Atrás o fuera del
diálogo "¿Descartar la alerta?", el sistema DEBE volver al formulario con
el tipo y los textos que había.

## Arrebato

## R40
SI `POST /alertas` recibe la categoría `arrebato` ENTONCES el sistema DEBE
responder 400 con `{"error": "Elegí qué tipo de alerta es."}`.

## R41
CUANDO la API responde `GET /alertas` con una alerta de categoría
`arrebato` ya guardada, el sistema DEBE devolverla con su categoría y su
título sin cambios.

## R42
CUANDO la app lee una alerta de categoría `arrebato` (de la API o de la
copia local), el sistema DEBE mostrarla con su título y con el ícono de
arrebato (`Icons.phone_android`).

## R43
El sistema DEBE crear los datos de ejemplo del backend y del servidor
simulado sin ninguna alerta de categoría `arrebato`.

## R44
El sistema DEBE incluir en los datos de ejemplo del backend y del servidor
simulado la alerta `a4` con categoría `robo`, título "Robo de celular" y la
misma descripción, dirección, ubicación, estado (`resuelta`) y autora
(`clara`) que tenía.

## Accesibilidad

## R45
El sistema DEBE dar a cada elemento tocable del botón "Reportar alerta",
del formulario y del diálogo "¿Descartar la alerta?" un área de al menos
48 x 48 dp.

## R46
El sistema DEBE anunciar en el lector de pantalla cada campo del
formulario con su nombre visible y cada tipo con su nombre y si está
elegido.

## R47
CUANDO aparece un error debajo de los tipos o un error de envío, el
sistema DEBE anunciarlo con una región en vivo (`liveRegion`) que muestre
un ícono además del texto.

## R48
MIENTRAS el texto del sistema está al 200 %, el sistema DEBE mostrar el
inicio con sus botones, el formulario (vacío y con errores) y el diálogo
"¿Descartar la alerta?" sin desbordes.

## R49
El sistema DEBE ordenar la lectura del formulario así: cerrar, título de
la pantalla, tipos, Título, Descripción, ubicación, Dirección, "Enviar
alerta", "Cancelar".

## R50
MIENTRAS el teclado en pantalla está abierto con el texto al 200 %, el
sistema DEBE permitir desplazar el formulario hasta el botón "Enviar
alerta" y tocarlo.

## El botón SOS (pedido en la aprobación)

> R51 a R53 se agregan después de R50 para no renumerar. Son el ajuste que
> pidió el equipo sobre R4: el SOS crece un poco para seguir siendo el
> botón que más se destaca en el inicio.

## R51
MIENTRAS el texto del sistema está al 100 %, el sistema DEBE mostrar el
botón SOS de las pantallas principales con 104 dp de alto, 216 dp de
ancho y el texto "SOS" en tamaño 32.

## R52
MIENTRAS el texto del sistema está al 200 % en una pantalla de 360 dp de
ancho, el sistema DEBE mostrar el botón SOS con al menos 104 dp de alto,
entero dentro del ancho de la pantalla y sin desbordes.

## R53
MIENTRAS el texto del sistema está al 200 % en una pantalla de 360 x 640
dp, el sistema DEBE permitir desplazar el inicio hasta que la tarjeta del
mapa se vea entera por encima del botón SOS y hasta que la última tarjeta
de "Alertas cerca tuyo" quede entera por encima del botón SOS.

## Trazabilidad con el `acceptance` de feature_list.json

| Criterio de aceptación | Cubierto por |
|---|---|
| En el inicio, debajo del mapa y arriba del botón Llamar al 911, hay un botón Reportar alerta del mismo ancho que el mapa | R1, R2, R4, R51 |
| El botón Llamar al 911 del inicio pasa a ocupar el mismo ancho que el mapa | R3, R4, R51 |
| Reportar alerta abre un formulario para elegir el tipo (Actividad sospechosa, Vehículo sospechoso, Robo o Ruidos), un título que el vecino puede ajustar, una descripción y la ubicación | R5, R6, R7, R8, R9, R10 |
| La ubicación sale del GPS del teléfono como en el SOS (o la zona del barrio si no dio permiso), con un campo para escribir la dirección | R11, R12, R13, R14, R15, R16 |
| Al enviar, la alerta queda creada con estado Activa y aparece en la lista y el mapa; si falla, el formulario lo dice y no se pierde lo escrito | R17, R18, R19, R20, R21, R22, R23, R24, R25, R26, R27, R28, R29, R30, R31, R32, R33, R34, R35, R36, R37, R38, R39 |
| Arrebato no aparece entre los tipos para elegir y la API rechaza una alerta nueva con categoría arrebato; las alertas de arrebato que ya existen se siguen viendo | R6, R31, R40, R41, R42 |
| Los datos de ejemplo (backend y servidor simulado) ya no crean alertas de arrebato | R43, R44 |
| El botón y el formulario cumplen las reglas de accesibilidad del proyecto | R4, R45, R46, R47, R48, R49, R50, R51, R52, R53 |
| Pruebas del ViewModel, del formulario, de la pantalla de inicio y del backend | R1 a R53 (cada uno con su prueba, ver `tasks.md`) |
