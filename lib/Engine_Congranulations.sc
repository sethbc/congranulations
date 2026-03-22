// Engine_Congranulations
// Granular synthesis engine for norns
// 4-voice polyphonic granulator with reverb send

Engine_Congranulations : CroneEngine {
  classvar nvoices = 4;

  var pg;
  var effect;
  var <buffersL;
  var <buffersR;
  var <voices;
  var mixBus;
  var <phases;
  var <levels;
  var seek_tasks;

  *new { arg context, doneCallback;
    ^super.new(context, doneCallback);
  }

  alloc {
    buffersL = Array.fill(nvoices, { Buffer.alloc(context.server, context.server.sampleRate * 10, 1) });
    buffersR = Array.fill(nvoices, { Buffer.alloc(context.server, context.server.sampleRate * 10, 1) });

    SynthDef(\congranulations_voice, {
      arg out, sendBus, bufL, bufR, gate = 1, pos = 0, speed = 1, size = 0.1,
          density = 10, spray = 0, amp = 0.5, send = 0,
          phaseOut, levelOut;
      var grainsL, grainsR, mix, env, trig, jitter, posModulated;

      env = EnvGen.kr(Env.asr(0.01, 1, 0.01), gate, doneAction: 0);

      // grain trigger: dust for organic density control
      trig = Dust.kr(density);

      // position with spray (random jitter)
      jitter = TRand.kr(spray.neg, spray, trig);
      posModulated = (pos + jitter).clip(0, 1);

      // stereo granulation from separate L/R buffers
      grainsL = GrainBuf.ar(
        numChannels: 1,
        trigger: trig,
        dur: size,
        sndbuf: bufL,
        rate: speed,
        pos: posModulated,
        interp: 4,
        pan: 0
      );

      grainsR = GrainBuf.ar(
        numChannels: 1,
        trigger: trig,
        dur: size,
        sndbuf: bufR,
        rate: speed,
        pos: posModulated,
        interp: 4,
        pan: 0
      );

      mix = [grainsL, grainsR] * env * amp;

      // polls: phase and level
      Out.kr(phaseOut, posModulated);
      Out.kr(levelOut, Amplitude.kr(Mix.ar(mix)));

      // dry signal to main out, wet to effect bus
      Out.ar(out, mix);
      Out.ar(sendBus, mix * send);
    }).add;

    SynthDef(\congranulations_effect, {
      arg in, out, reverb = 0.5, room = 0.7, damp = 0.5;
      var sig, wet;

      sig = In.ar(in, 2);
      wet = FreeVerb2.ar(sig[0], sig[1], mix: reverb, room: room, damp: damp);
      Out.ar(out, wet);
    }).add;

    context.server.sync;

    // mix bus for routing voices -> effect
    mixBus = Bus.audio(context.server, 2);

    // control buses for polls
    phases = Array.fill(nvoices, { Bus.control(context.server) });
    levels = Array.fill(nvoices, { Bus.control(context.server) });

    // voice group for parallel execution
    pg = ParGroup.head(context.xg);

    // instantiate voices
    voices = Array.fill(nvoices, { arg i;
      Synth.new(\congranulations_voice, [
        \out, context.out_b.index,
        \sendBus, mixBus.index,
        \bufL, buffersL[i],
        \bufR, buffersR[i],
        \pos, 0,
        \speed, 1,
        \size, 0.1,
        \density, 10,
        \spray, 0.01,
        \amp, 0.5,
        \send, 0,
        \phaseOut, phases[i].index,
        \levelOut, levels[i].index
      ], target: pg);
    });

    // effect synth — after voices in execution order
    effect = Synth.after(pg, \congranulations_effect, [
      \in, mixBus.index,
      \out, context.out_b.index,
      \reverb, 0.5,
      \room, 0.7,
      \damp, 0.5
    ]);

    context.server.sync;

    // seek tasks for smooth position changes
    seek_tasks = Array.newClear(nvoices);

    //
    // Commands
    //

    // read: load a sample into a voice (voice index, file path)
    this.addCommand("read", "is", { arg msg;
      this.readBuf(msg[1] - 1, msg[2]);
    });

    // pos: set grain position 0..1 (voice index, value)
    this.addCommand("pos", "if", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\pos, msg[2]);
    });

    // speed: set playback speed/pitch (voice index, value)
    this.addCommand("speed", "if", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\speed, msg[2]);
    });

    // size: set grain size in seconds (voice index, value)
    this.addCommand("size", "if", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\size, msg[2]);
    });

    // density: set grain density/trigger rate (voice index, value)
    this.addCommand("density", "if", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\density, msg[2]);
    });

    // spray: set position jitter/randomness (voice index, value)
    this.addCommand("spray", "if", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\spray, msg[2]);
    });

    // amp: set voice amplitude (voice index, value)
    this.addCommand("amp", "if", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\amp, msg[2]);
    });

    // send: set reverb send level (voice index, value)
    this.addCommand("send", "if", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\send, msg[2]);
    });

    // gate: open/close voice gate (voice index, 0 or 1)
    this.addCommand("gate", "ii", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\gate, msg[2]);
    });

    // seek: smoothly move position over time (voice index, target pos)
    this.addCommand("seek", "if", { arg msg;
      var voice = msg[1] - 1;
      var target = msg[2];
      seek_tasks[voice].stop;
      seek_tasks[voice] = Routine {
        var current;
        voices[voice].get(\pos, { arg val; current = val });
        context.server.sync;
        20.do { arg i;
          var t = (i + 1) / 20;
          voices[voice].set(\pos, current + ((target - current) * t));
          0.01.wait;
        };
      }.play;
    });

    // reverb: set reverb mix (0..1)
    this.addCommand("reverb", "f", { arg msg;
      effect.set(\reverb, msg[1]);
    });

    // room: set reverb room size (0..1)
    this.addCommand("room", "f", { arg msg;
      effect.set(\room, msg[1]);
    });

    // damp: set reverb damping (0..1)
    this.addCommand("damp", "f", { arg msg;
      effect.set(\damp, msg[1]);
    });

    //
    // Polls
    //

    nvoices.do({ arg i;
      this.addPoll(("phase_" ++ (i + 1)).asSymbol, {
        phases[i].getSynchronous;
      });

      this.addPoll(("level_" ++ (i + 1)).asSymbol, {
        levels[i].getSynchronous;
      });
    });
  }

  readBuf { arg voice, path;
    if(buffersL[voice].notNil && buffersR[voice].notNil, {
      Buffer.readChannel(context.server, path, channels: [0], action: { arg buf;
        buffersL[voice].free;
        buffersL[voice] = buf;
        voices[voice].set(\bufL, buf);
      });
      Buffer.readChannel(context.server, path, channels: [1], action: { arg buf;
        buffersR[voice].free;
        buffersR[voice] = buf;
        voices[voice].set(\bufR, buf);
      });
    });
  }

  free {
    voices.do({ arg voice; voice.free });
    phases.do({ arg bus; bus.free });
    levels.do({ arg bus; bus.free });
    buffersL.do({ arg buf; buf.free });
    buffersR.do({ arg buf; buf.free });
    effect.free;
    mixBus.free;
    seek_tasks.do({ arg task; if(task.notNil, { task.stop }) });
  }
}
