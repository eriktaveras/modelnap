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

print(failures == 0 ? "todo bien" : "\(failures) fallos")
exit(failures == 0 ? 0 : 1)
