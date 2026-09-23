"""Five small original synthesized UI cues. No external audio service."""
from pathlib import Path
import wave
import math
import struct

destination = Path(__file__).resolve().parents[1] / 'game' / 'assets' / 'audio'
for name, hz, seconds in [('interact', 440, .10), ('pulse', 180, .35), ('evidence', 660, .25), ('impact', 90, .20), ('change', 330, .7)]:
    rate = 22050
    samples = []
    for n in range(int(rate * seconds)):
        t = n / rate
        envelope = min(1, t / .01) * (1-t/seconds) ** 2
        phase = 2*math.pi*(hz*t + (300*t*t if name in ('pulse', 'change') else 0))
        sample = .22 * envelope * (math.sin(phase) + .25*math.sin(phase*1.5))
        samples.append(struct.pack('<h', int(max(-1, min(1, sample)) * 32767)))
    with wave.open(str(destination / f'{name}.wav'), 'wb') as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(rate)
        stream.writeframes(b''.join(samples))
