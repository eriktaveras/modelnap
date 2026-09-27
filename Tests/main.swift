import Foundation

// Banco de pruebas de IdleTracker: ./build.sh --test
var failures = 0
func check(_ name: String, _ ok: Bool) {
    print(ok ? "✓ \(name)" : "✗ \(name)")
    if !ok { failures += 1 }
}

let t0 = Date(timeIntervalSince1970: 1_000_000)
func at(_ s: TimeInterval) -> Date { t0.addingTimeInterval(s) }

var tr = IdleTracker(now: t0)
tr.sample(cpu: [100: 6.590], models: ["gemma4"], now: at(0))
check("un modelo nuevo cuenta como uso", tr.idleSeconds(now: at(0)) == 0)

// Reposo medido: +0,003 s y +0,058 s en tandas de 15 s.
tr.sample(cpu: [100: 6.593], models: ["gemma4"], now: at(15))
tr.sample(cpu: [100: 6.651], models: ["gemma4"], now: at(30))
check("el ruido de reposo no reinicia el contador", tr.idleSeconds(now: at(30)) == 30)

// Generar 104 tokens: +0,988 s.
tr.sample(cpu: [100: 7.639], models: ["gemma4"], now: at(40))
check("generar reinicia el contador", tr.idleSeconds(now: at(40)) == 0)

tr.sample(cpu: [100: 7.645], models: ["gemma4"], now: at(100))
check("vuelve a contar tras generar", tr.idleSeconds(now: at(100)) == 60)

tr.sample(cpu: [200: 0.5], models: ["gemma4"], now: at(110))
check("un runner distinto (recarga) cuenta como uso", tr.idleSeconds(now: at(110)) == 0)

tr.sample(cpu: [200: 0.5], models: ["qwen"], now: at(120))
check("cambiar de modelo cuenta como uso", tr.idleSeconds(now: at(120)) == 0)

tr.sample(cpu: [200: 0.5], models: ["qwen"], now: at(200))
tr.touch(now: at(210))
check("una acción manual cuenta como uso", tr.idleSeconds(now: at(215)) == 5)

tr.sample(cpu: [200: 0.3], models: ["qwen"], now: at(220))
check("un contador de CPU que baja no rompe nada", tr.idleSeconds(now: at(220)) == 10)

tr.sample(cpu: [200: 0.3 + IdleTracker.activityThreshold], models: ["qwen"], now: at(230))
check("justo en el umbral cuenta como uso", tr.idleSeconds(now: at(230)) == 0)

// Splash: el contador sale de /status, no del CPU.
func splash(_ submitted: Int64, busy: Bool = false) -> SplashStatus {
    SplashStatus(ready: true, model: "incoai/Qwen3.8-27B-Splash", bytes: 19_055_050_752, submitted: submitted, busy: busy)
}
var sa = SplashActivity(now: t0)
sa.sample(splash(2), now: at(0))
sa.sample(splash(2), now: at(60))
check("Splash: sin peticiones nuevas cuenta como reposo", sa.idleSeconds(now: at(60)) == 60)

sa.sample(splash(2, busy: true), now: at(70))
check("Splash: una petición en curso es uso", sa.idleSeconds(now: at(70)) == 0)

sa.sample(splash(2), now: at(100))
sa.sample(splash(3), now: at(130))
check("Splash: una petición que empezó y acabó entre muestras es uso", sa.idleSeconds(now: at(130)) == 0)

sa.sample(splash(3), now: at(190))
check("Splash: vuelve a contar tras la petición", sa.idleSeconds(now: at(190)) == 60)

sa.sample(splash(0), now: at(200))
check("Splash: un reinicio del servidor (contador a 0) es uso", sa.idleSeconds(now: at(200)) == 0)

print(failures == 0 ? "todo bien" : "\(failures) fallos")
exit(failures == 0 ? 0 : 1)
