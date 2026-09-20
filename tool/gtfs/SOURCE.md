# Origen del feed

`mex-ags-ags.zip` es el GTFS estático del transporte público concesionado de Aguascalientes.
Se versiona aquí para que la conversión se reproduzca sin red y sin depender de que la URL siga viva.

| | |
|---|---|
| Publica | Gobierno del Estado de Aguascalientes — Coordinación General de Movilidad (CMOV) |
| Se distribuye en | https://hdtp.codeandomexico.org/datos/mex-ags-ags |
| Descarga directa | https://hdtp.codeandomexico.org/gtfs/mex-ags-ags.zip |
| Licencia | Creative Commons Atribución-CompartirIgual 4.0 Internacional (CC BY-SA 4.0) |
| `feed_version` | `20250902` |
| Vigencia declarada | `20230101`–`20251231` |
| Descargado | 20 de septiembre de 2026 |
| SHA-256 | `3fe35e5d882881da6bb751c6c058c3755a8ca51deb8488568d1e5cb4aa7887a3` |
| Tamaño | 447 090 bytes |

## Qué trae

```
agency.txt        1 agencia
routes.txt       48 rutas, con color real
trips.txt       184 viajes (ida y vuelta por ruta)
shapes.txt       92 trazos, 41 252 puntos
stops.txt     1 507 paradas
stop_times.txt 8 388 filas
frequencies.txt 184 headways
calendar.txt      2 servicios: ES (lun–vie) y FS (sáb–dom)
```

No trae `calendar_dates.txt`, `stop_code`, `wheelchair_boarding` ni `trip_headsign`.

## Cómo se actualiza

1. Descargar el zip nuevo y sustituir este archivo.
2. Actualizar la tabla de arriba: `feed_version`, fecha y SHA-256.
3. Correr `python tool/gtfs_to_mock.py` desde la raíz del proyecto.
4. Correr `flutter test test/core/models/mock_dataset_test.dart`. Los conteos que el test verifica
   van a cambiar y hay que actualizarlos a mano: es a propósito, para que un feed distinto se note.
