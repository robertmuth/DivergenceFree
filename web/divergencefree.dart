import 'dart:math';
import 'dart:html' as HTML;
import 'dart:math' as Math;

import 'dart:typed_data';
import 'dart:async';

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as VM;

import 'logging.dart' as log;
import 'option.dart';
import 'webutil.dart';
import 'rgb.dart';
import 'color_rotator.dart';

import 'snoise.dart';

final bool gDebug = true && false;

const String uAspectRatio = "uAspectRatio";
const String uBorder = "uBorder";
const String uGain = "uGain";

final HTML.CanvasElement gCanvas = HTML.document.querySelector('#area');
Options gOptions = null;
final HTML.Element gFps = HTML.querySelector("#fps");

typedef double NoiseFun(double x, double y, double z);

void HandleCommand(String cmd, String param) {
  log.LogInfo("HandleCommand: ${cmd} ${param}");
  switch (cmd) {
    case "A":
      Toggle(HTML.querySelector(".about"));
      break;
    case "C":
      Toggle(HTML.querySelector(".config"));
      break;
    case "P":
      Toggle(HTML.querySelector(".performance"));
      break;
    case "R":
      gOptions.SaveToLocalStorage();
      HTML.window.location.hash = "";
      HTML.window.location.reload();
      break;
    case "A+":
      Show(HTML.querySelector(".about"));
      break;
    case "A-":
      Hide(HTML.querySelector(".about"));
      break;
    case "F":
      ToggleFullscreen();
      break;
    case "C-":
      Hide(HTML.querySelector(".config"));
      break;
    case "C+":
      Show(HTML.querySelector(".config"));
      break;
    case "X":
      String preset =
          (HTML.querySelector("#preset") as HTML.SelectElement).value;
      gOptions.SetNewSettings(preset);
      HTML.window.location.reload();

      break;
  }
}

void OptionsSetup() {
  gOptions = new Options("divergencefree")
    ..AddOption("hideAbout", "B", "false")
    ..AddOption("randomSeed", "I", "0")
    ..AddOption("scale", "D", "10.0")
    ..AddOption("gain", "D", "7.0")
    ..AddOption("change", "D", "0.0")
    ..AddOption("pointsize", "D", "2.5")
    ..AddOption("particles", "I", "40000")
    ..AddOption("backgroundColor", "S", "black")
    ..AddOption("foregroundColor", "S", "blue");

  gOptions.AddSetting("Standard", {
    "pointsize": "2.5",
    "backgroundColor": "black",
    "foregroundColor": "blue",
    "scale": "10",
    "gain": "7",
    "particles": "40000",
    "change": "0.0",
  });

  gOptions.AddSetting("BlueLarge", {
    "pointsize": "4.5",
    "backgroundColor": "black",
    "foregroundColor": "blue",
    "scale": "50",
    "gain": "50",
    "particles": "10000",
    "change": "0.0",
  });

  gOptions.AddSetting("BlueLargeChanging", {
    "pointsize": "4.5",
    "backgroundColor": "black",
    "foregroundColor": "blue",
    "scale": "50",
    "gain": "50",
    "particles": "10000",
    "change": "20.0",
  });

  gOptions.AddSetting("GreenHuge", {
    "pointsize": "4.5",
    "backgroundColor": "black",
    "foregroundColor": "green",
    "scale": "150",
    "gain": "150",
    "particles": "10000",
    "change": "0.0",
  });

  gOptions.AddSetting("RedMedium", {
    "pointsize": "2.5",
    "backgroundColor": "black",
    "foregroundColor": "red",
    "scale": "20",
    "gain": "20",
    "particles": "10000",
    "change": "0.0",
  });

  gOptions.AddSetting("RedMediumDense", {
    "pointsize": "2.5",
    "backgroundColor": "black",
    "foregroundColor": "red",
    "scale": "20",
    "gain": "20",
    "particles": "50000",
    "change": "0.0",
  });

  gOptions.AddSetting("AnimatedForeground", {
    "pointsize": "4.5",
    "backgroundColor": "black",
    "foregroundColor": "animated",
    "scale": "50",
    "gain": "50",
    "particles": "10000",
    "change": "0.0",
  });

  gOptions.AddSetting("AnimatedBackground", {
    "pointsize": "4.5",
    "backgroundColor": "animated",
    "foregroundColor": "black",
    "scale": "50",
    "gain": "50",
    "particles": "10000",
    "change": "0.0",
  });

  gOptions.AddSetting("BlackLarge", {
    "pointsize": "4.5",
    "backgroundColor": "white",
    "foregroundColor": "black",
    "scale": "50",
    "gain": "50",
    "particles": "10000",
    "change": "0.0",
  });

  gOptions.AddSetting("WhiteLarge", {
    "pointsize": "2c.0",
    "backgroundColor": "black",
    "foregroundColor": "white",
    "scale": "50",
    "gain": "50",
    "particles": "10000",
    "change": "0.0",
  });

  gOptions.ProcessUrlHash();

  if (gOptions.GetBool("hideAbout")) {
    var delay = const Duration(seconds: 4);
    new Timer(delay, () => Hide(HTML.querySelector(".about")));
  }

  HTML.SelectElement presets = HTML.querySelector("#preset");
  for (String name in gOptions.SettingsNames()) {
    HTML.OptionElement o = new HTML.OptionElement(data: name, value: name);
    presets.append(o);
  }
}

const String speedAndPotentialHelpers = """
const float epsilon = 1e-5;
const float inv2epsilon = 1.0 / (2.0 * epsilon); 
const float dt = 0.00001;

// Note, this needs to be continous
float border(float x, float y) {
    float dx = ${uAspectRatio} - abs(x);
    float dy = 1.0 - abs(y);
    float px =  dx > ${uBorder} ? 1.0 : smoothstep(0.0, 1.0, dx / ${uBorder});
    float py =  dy > ${uBorder} ? 1.0 : smoothstep(0.0, 1.0, dy / ${uBorder});
    return px * py;
}

float GetPotential(float x, float y, float t) {
   if (t == 0.0) {
       return border(x, y) * ${uGain} * snoise2(vec2(x * ${uScale}, y * ${uScale}));         
   } else {
       return border(x, y) * ${uGain} * snoise3(vec3(x * ${uScale}, y * ${uScale}, t));
   }          
}

vec2 GetSpeed(float x, float y, float t) {
   float dx = GetPotential(x, y + epsilon, t) - GetPotential(x, y - epsilon, t);
   float dy = GetPotential(x + epsilon, y, t) - GetPotential(x - epsilon, y, t);
   return vec2 (-dx * inv2epsilon, dy * inv2epsilon);
}

vec3 Update(vec3 pos) {
   // http://mathworld.wolfram.com/Runge-KuttaMethod.html
   vec2 mid = pos.xy + 0.5 * dt * GetSpeed(pos.x, pos.y, ${uTime});
   pos.xy += dt * GetSpeed(mid.x, mid.y, ${uTime});
   return pos;
}

""";

final ShaderObject particleUpdaterV = new ShaderObject("ParticleV")
  ..AddAttributeVars([aPosition])
  ..AddUniformVars([uTime, uPointSize, uScale, uGain, uBorder, uAspectRatio])
  ..AddTransformVars([tPosition])
  ..SetBody([
    SimplexNoiseHelpers,
    SimplexNoiseFunction2,
    SimplexNoiseFunction3,
    speedAndPotentialHelpers,
    """

      
void main() {
    gl_PointSize = ${uPointSize};
    gl_Position.xyz = ${aPosition};
    gl_Position.x /= ${uAspectRatio};
    gl_Position.a = 1.0;        
    // new position for next round
    ${tPosition} = Update(${aPosition});
}
"""
  ]);

final ShaderObject particleUpdaterF = new ShaderObject("ParticleF")
  ..AddUniformVars([uColor])
  ..SetBody([
    """
void main() {
      float r = length(gl_PointCoord.xy - vec2(0.5, 0.5));
      ${oFragColor}.rgb = (r >= 0.5) ? vec3(0.0) : ${uColor};
      ${oFragColor}.a = 1.0;
}
"""
  ]);

final ShaderObject blurdVertexShader = new ShaderObject("bluredV")
  ..AddAttributeVars([aPosition])
  ..SetBodyWithMain([NullVertexBody]);

final ShaderObject bluredFragmentShader = new ShaderObject("bluredF")
  ..AddUniformVars([uColorAlpha])
  ..SetBodyWithMain(["${oFragColor} = ${uColorAlpha};"]);

RenderPhase Particles(ChronosGL cgl, RenderProgram program, Material mat, Material matBlur,
    MeshData particles) {
  RenderPhase phase = new RenderPhase("particles", cgl);
  phase.clearColorBuffer = false;

  {
    Scene scene = new Scene(
        "blur",
        new RenderProgram("blur", cgl, blurdVertexShader, bluredFragmentShader),
        []);
    phase.add(scene);

    scene.add(new Node("", ShapeQuad(scene.program, 1), matBlur));
  }
  {
    Scene scene = new Scene("particles", program, []);
    phase.add(scene);
    scene.add(new Node("particles", particles, mat));
  }
  return phase;
}

VM.Vector3 RandomColor(Math.Random rng) {
  return new VM.Vector3(rng.nextDouble(), rng.nextDouble(), rng.nextDouble());
}


VM.Vector3 TranslateColor(String color, VM.Vector3 random, ColorRotator colorrot) {
  if (color == "random") {
    return random;
  } else if (color == "animated") {
     return
           new VM.Vector3(colorrot.r, colorrot.g, colorrot.b);
  }
  RGB rgb = new RGB.fromName(color);
  return rgb.GlColor();
}

void main() {
  print("startup");
  IntroduceNewShaderVar(uAspectRatio, new ShaderVarDesc("float", ""));
  IntroduceNewShaderVar(uBorder, new ShaderVarDesc("float", ""));
  IntroduceNewShaderVar(uGain, new ShaderVarDesc("float", ""));

  if (!HasWebGLSupport()) {
    HTML.window.alert("Your browser does not support WebGL.");
    return;
  }
  OptionsSetup();
  int seed = gOptions.GetInt("randomSeed");
  if (seed == 0) {
    seed = new DateTime.now().millisecondsSinceEpoch;
  }
  final Random rng = new Math.Random(seed);
  final int numParticles = gOptions.GetInt("particles");

  final ColorRotator colorrot = new ColorRotator(rng, 10 * 0.02, 0.0, 0.0);
  final VM.Vector3 fgRandomColor = RandomColor(rng);
  final VM.Vector3 bgRandomColor = RandomColor(rng);

  ChronosGL cgl =
      new ChronosGL(gCanvas, faceCulling: true, preserveDrawingBuffer: true);

  final Material matParticles =
      new Material.Transparent("stars", BlendEquationStandard)
        ..SetUniform(uModelMatrix, new VM.Matrix4.identity())
        ..SetUniform(uPointSize, 5.0);

  // Every frame 4% of the screen will be blurred
    Material matBlur = new Material.Transparent("blur", BlendEquationStandard);
      //..SetUniform(uColorAlpha, new VM.Vector4(bg.r, bg.g, bg.b, 0.04));

  final borderWidth = 0.02;
  final RenderProgram programParticle =
      new RenderProgram("", cgl, particleUpdaterV, particleUpdaterF);
  final int bindingIndex = programParticle.GetTransformBindingIndex(tPosition);

  final MeshData mdOut = programParticle.MakeMeshData("ionsOut", GL_POINTS);
  final MeshData mdIn = programParticle.MakeMeshData("ionsIn", GL_POINTS);

  final RenderPhase phaseParticle =
      Particles(cgl, programParticle, matParticles, matBlur, mdIn);

  var transform = cgl.createTransformFeedback();
  cgl.bindTransformFeedback(transform);

  void resolutionChange(HTML.Event ev) {
    gCanvas.width = HTML.window.innerWidth;
    gCanvas.height = HTML.window.innerHeight;
    int w = gCanvas.clientWidth;
    int h = gCanvas.clientHeight;
    gCanvas.width = w;
    gCanvas.height = h;
    print("size change $w $h");

    phaseParticle.viewPortH = h;
    phaseParticle.viewPortW = w;
    matParticles.ForceUniform(uAspectRatio, w / h);

    final Float32List partPos = new Float32List(3 * numParticles);
    for (int i = 0; i < partPos.length; ++i) {
      partPos[i] = (rng.nextDouble() - 0.5) * (2.0 - 2 * borderWidth);
      if (i % 3 == 0) partPos[i] *= w / h;
    }
    if (ev == null) {
      mdOut.AddVertices(partPos);
      mdIn.AddVertices(partPos);
    } else {
      mdOut.ChangeVertices(partPos);
      mdIn.ChangeVertices(partPos);
    }
    cgl.bindBuffer(GL_ARRAY_BUFFER, null);
    cgl.bindBufferBase(GL_TRANSFORM_FEEDBACK_BUFFER, bindingIndex, null);

    cgl.bindBufferBase(
        GL_TRANSFORM_FEEDBACK_BUFFER, bindingIndex, mdOut.GetBuffer(aPosition));
  }

  resolutionChange(null);
  HTML.window.onResize.listen(resolutionChange);

  VM.Vector4 bg = new VM.Vector4(0.0, 0.0, 0.0, 0.04);
  double _lastTimeMs = 0.0;
  int ticks = 0;
  void tick(num timeMs) {
    ticks++;
    timeMs = 0.0 + timeMs;
    double elapsedMs = timeMs - _lastTimeMs;
    _lastTimeMs = timeMs;
    colorrot.Update(elapsedMs / 500.0);

    final double gain = gOptions.GetDouble("gain");
    final double pointsize = gOptions.GetDouble("pointsize");
    final double scale = gOptions.GetDouble("scale");
    final double changeRate = gOptions.GetDouble("change");
    final String fgColor = gOptions.Get("foregroundColor");
    final String bgColor = gOptions.Get("backgroundColor");

    // fight fix points with a jolt of noise occasionally.
    double noise = ticks % 500 == 0 ? 1.0 + 0.02 : 1.0;

    double t = timeMs * changeRate * 0.001 * 0.001;
    matParticles
      ..ForceUniform(uTime, t)
      ..ForceUniform(uPointSize, pointsize)
      ..ForceUniform(uGain, gain)
      // add a tiny bit of noise to avoid "orbits
      ..ForceUniform(uScale, 100.0 / scale * noise)
      ..ForceUniform(uBorder, scale * 0.002)
      ..ForceUniform(
            uColor, TranslateColor(fgColor, fgRandomColor, colorrot));

    bg.rgb = TranslateColor(bgColor, bgRandomColor, colorrot);
    matBlur.ForceUniform(uColorAlpha, bg);

    phaseParticle.Draw();

    cgl.bindBuffer(GL_ARRAY_BUFFER, mdIn.GetBuffer(aPosition));
    cgl.bindBuffer(GL_TRANSFORM_FEEDBACK_BUFFER, mdOut.GetBuffer(aPosition));
    cgl.copyBufferSubData(GL_TRANSFORM_FEEDBACK_BUFFER, GL_ARRAY_BUFFER, 0, 0,
        numParticles * 3 * 4);

    HTML.window.animationFrame.then(tick);
    UpdateFrameCount(timeMs, gFps, "");
  }

  HTML.document.body.onKeyDown.listen((HTML.KeyboardEvent e) {
    log.LogInfo("key pressed ${e.which} ${e.target.runtimeType}");
    if (e.target.runtimeType == HTML.InputElement) {
      return;
    }
    String cmd = new String.fromCharCodes([e.which]);
    HandleCommand(cmd, "");
  });

  HTML.ElementList<HTML.Element> buttons =
      HTML.document.body.querySelectorAll("button");

  log.LogInfo("found ${buttons.length} buttons");
  buttons.onClick.listen((HTML.Event ev) {
    String cmd = (ev.target as HTML.Element).dataset['cmd'];
    String param = (ev.target as HTML.Element).dataset['param'];
    HandleCommand(cmd, param);
  });

  tick(0.0);
}
