import ddf.minim.*;
import java.util.List;
import java.io.File;

Minim minim;
AudioInput mic;

PShape svgShape;
ArrayList<PVector> basePoints = new ArrayList<PVector>();
ArrayList<PVector> normalizedPoints = new ArrayList<PVector>();

Slider spacingSlider;
Slider sizeSlider;
Slider wiggleSlider;

float pointSpacing = 16;  // pixels between sampled points
float dotSize = 4;
float wiggleIntensity = 60;

boolean needsResample = false;

int margin = 60;

void setup() {
  size(800, 600, P2D);
  surface.setTitle("SVG Audio Dots");
  background(0);

  minim = new Minim(this);
  mic = minim.getLineIn(Minim.MONO, 2048);

  spacingSlider = new Slider(20, height - 120, 220, 18, 6, 40, pointSpacing, "Dot spacing");
  sizeSlider = new Slider(20, height - 85, 220, 18, 2, 16, dotSize, "Dot size");
  wiggleSlider = new Slider(20, height - 50, 220, 18, 0, 180, wiggleIntensity, "Wiggle intensity");

  loadDefaultSvg();
}

void draw() {
  background(0);

  if (needsResample) {
    pointSpacing = spacingSlider.getValue();
    dotSize = sizeSlider.getValue();
    wiggleIntensity = wiggleSlider.getValue();
    rebuildPoints();
    needsResample = false;
  }

  float level = mic != null ? mic.mix.level() : 0;
  drawPoints(level);
  drawUi(level);
}

void loadDefaultSvg() {
  PShape svg = loadShape("data/sample.svg");
  if (svg != null) {
    setSvg(svg);
  }
}

void setSvg(PShape newSvg) {
  this.svgShape = newSvg;
  rebuildPoints();
}

void rebuildPoints() {
  basePoints.clear();
  normalizedPoints.clear();
  if (svgShape == null) return;

  extractPoints(svgShape, basePoints);
  normalizePoints();
}

void extractPoints(PShape shape, List<PVector> collector) {
  if (shape.getChildCount() > 0) {
    for (int i = 0; i < shape.getChildCount(); i++) {
      extractPoints(shape.getChild(i), collector);
    }
    return;
  }

  int count = shape.getVertexCount();
  if (count < 2) return;

  boolean closeLoop = shape.isClosed();
  for (int i = 0; i < count; i++) {
    PVector v1 = shape.getVertex(i);
    PVector v2;
    if (i == count - 1) {
      if (!closeLoop) break;
      v2 = shape.getVertex(0);
    } else {
      v2 = shape.getVertex(i + 1);
    }

    float segLen = PVector.dist(v1, v2);
    int steps = max(1, int(segLen / pointSpacing));
    for (int s = 0; s < steps; s++) {
      float t = s / (float) steps;
      float x = lerp(v1.x, v2.x, t);
      float y = lerp(v1.y, v2.y, t);
      collector.add(new PVector(x, y));
    }
  }
}

void normalizePoints() {
  if (basePoints.isEmpty()) return;

  float minX = Float.MAX_VALUE;
  float minY = Float.MAX_VALUE;
  float maxX = Float.MIN_VALUE;
  float maxY = Float.MIN_VALUE;

  for (PVector p : basePoints) {
    if (p.x < minX) minX = p.x;
    if (p.y < minY) minY = p.y;
    if (p.x > maxX) maxX = p.x;
    if (p.y > maxY) maxY = p.y;
  }

  float w = maxX - minX;
  float h = maxY - minY;
  float availableW = width - margin * 2;
  float availableH = height - margin * 2;
  float scale = min(availableW / w, availableH / h);

  float offsetX = (width - w * scale) * 0.5f - minX * scale;
  float offsetY = (height - h * scale) * 0.5f - minY * scale;

  normalizedPoints.clear();
  for (PVector p : basePoints) {
    normalizedPoints.add(new PVector(p.x * scale + offsetX, p.y * scale + offsetY));
  }
}

void drawPoints(float audioLevel) {
  if (normalizedPoints.isEmpty()) {
    fill(255);
    textAlign(CENTER, CENTER);
    text("Load an SVG to start", width/2, height/2);
    return;
  }

  noStroke();
  fill(255);
  float t = frameCount * 0.01f;
  float wiggle = audioLevel * wiggleIntensity;

  for (int i = 0; i < normalizedPoints.size(); i++) {
    PVector p = normalizedPoints.get(i);
    float n1 = noise(p.x * 0.01f, p.y * 0.01f, t + i * 0.05f);
    float angle = (n1 - 0.5f) * TWO_PI;
    float mag = wiggle * (0.5f + noise(t * 0.5f + i));
    float ox = cos(angle) * mag;
    float oy = sin(angle) * mag;
    ellipse(p.x + ox, p.y + oy, dotSize, dotSize);
  }
}

void drawUi(float level) {
  spacingSlider.display();
  sizeSlider.display();
  wiggleSlider.display();

  fill(200);
  textAlign(LEFT, CENTER);
  text("Mic level: " + nf(level, 1, 3), spacingSlider.x + spacingSlider.w + 16, height - 50);
  text("Press 'o' to open an SVG file", spacingSlider.x + spacingSlider.w + 16, height - 70);
}

void mousePressed() {
  if (spacingSlider.handleMouse(mouseX, mouseY)) needsResample = true;
  else if (sizeSlider.handleMouse(mouseX, mouseY)) needsResample = true;
  else if (wiggleSlider.handleMouse(mouseX, mouseY)) needsResample = true;
}

void mouseDragged() {
  if (spacingSlider.handleMouse(mouseX, mouseY)) needsResample = true;
  else if (sizeSlider.handleMouse(mouseX, mouseY)) needsResample = true;
  else if (wiggleSlider.handleMouse(mouseX, mouseY)) needsResample = true;
}

void keyPressed() {
  if (key == 'o' || key == 'O') {
    selectInput("Choose an SVG file", "fileSelected");
  }
}

void fileSelected(File selection) {
  if (selection == null) {
    println("File selection was canceled.");
  } else {
    String path = selection.getAbsolutePath();
    PShape svg = loadShape(path);
    if (svg != null) {
      setSvg(svg);
    } else {
      println("Could not load SVG: " + path);
    }
  }
}

void drop(File file) {
  if (file != null && file.getName().toLowerCase().endsWith(".svg")) {
    PShape svg = loadShape(file.getAbsolutePath());
    if (svg != null) {
      setSvg(svg);
    }
  }
}

class Slider {
  float x, y, w, h;
  float minVal, maxVal;
  float value;
  String label;
  boolean active = false;

  Slider(float x, float y, float w, float h, float minVal, float maxVal, float value, String label) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.minVal = minVal;
    this.maxVal = maxVal;
    this.value = constrain(value, minVal, maxVal);
    this.label = label;
  }

  void display() {
    stroke(120);
    fill(40);
    rect(x, y, w, h, 4);

    float pos = map(value, minVal, maxVal, x, x + w);
    fill(255);
    ellipse(pos, y + h / 2, h + 6, h + 6);

    noStroke();
    fill(200);
    textAlign(LEFT, CENTER);
    text(label + ": " + nfc(value, 1), x + w + 10, y + h / 2);
  }

  boolean handleMouse(float mx, float my) {
    if (mousePressed && (active || over(mx, my))) {
      active = true;
      float t = constrain((mx - x) / w, 0, 1);
      value = lerp(minVal, maxVal, t);
      return true;
    } else {
      active = false;
    }
    return false;
  }

  boolean over(float mx, float my) {
    return mx >= x && mx <= x + w && my >= y - 6 && my <= y + h + 6;
  }

  float getValue() {
    return value;
  }
}

void stop() {
  if (mic != null) {
    mic.close();
  }
  if (minim != null) {
    minim.stop();
  }
  super.stop();
}
