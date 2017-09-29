/*
Copyright Robert Muth <robert@muth.org>

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; version 3
of the License.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/

library color_rotator;

import 'dart:math' as Math;

double _hue2rgb(double p, double q, double t) {
  if (t < 0.0) t += 1.0;
  if (t > 1.0) t -= 1.0;
  if (t < 1 / 6) return p + (q - p) * 6.0 * t;
  if (t < 1 / 2) return q;
  if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6.0;
  return p;
}

class ColorRotator {
  double r, g, b;
  //
  double _srcH, _srcS, _srcL;
  double _dstH, _dstS, _dstL;
  double h = 0.5, s = 0.5, l = 0.5;
  double _interpolate = 1.0;
  double _change = 1.0;
  final double _speedNoise;
  final double _drasticProb;
  final double _speed;
  final Math.Random _rng;

  ColorRotator(this._rng, this._speed, this._drasticProb, [this._speedNoise = 0.5]) {
    h = _rng.nextDouble();
    h = 1.0 - _rng.nextDouble() * _rng.nextDouble();
    l = 1.0;
  }

  void _ComputeCurrentColor() {
    double delta;
    delta = _dstH - _srcH;
    if (delta < -0.5 || (0.0 < delta && delta < 0.5)) {
      h = _srcH + _interpolate * delta;
    } else {
      h = _srcH - _interpolate * delta;
    }
    if (h < 0.0) h += 1.0;
    if (h > 1.0) h -= 1.0;
    delta = _dstS - _srcS;
    s = _srcS + _interpolate * delta;
    l = 1.0;
  }

  _ComputeRGB2() {
    if (s == 0.0) {
      r = l;
      g = l;
      b = l;
      return;
    }
    double q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    double p = 2.0 * l - q;
    print("pq: $p $q");
    r = _hue2rgb(p, q, h + 1 / 3);
    g = _hue2rgb(p, q, h);
    b = _hue2rgb(p, q, h - 1 / 3);
  }

  _ComputeRGB() {
    if (h < 1.0 / 6.0) {
      // full red, some green
      r = 1.0;
      g = h * 6.0;
      b = 0.0;
    } else {
      if (h < 0.5) {
        // full green
        g = 1.0;
        if (h < 1.0 / 3.0) {
          // some red
          r = 1.0 - ((h - 1.0 / 6.0) * 6.0);
          b = 0.0;
        } else {
          // some blue
          b = (h - 1.0 / 3.0) * 6.0;
          r = 0.0;
        }
      } else {
        if (h < 5.0 / 6.0) {
          // full blue
          b = 1.0;
          if (h < 2.0 / 3.0) {
            // some green
            g = 1.0 - ((h - 0.5) * 6.0);
            r = 0.0;
          } else {
            // some red
            r = (h - 0.666667) * 6.0;
            g = 0.0;
          }
        } else {
          // full red, some blue
          r = 1.0;
          b = 1.0 - ((h - 5.0 / 6.0) * 6.0);
          g = 0.0;
        }
      }
    }
    // saturation influence
    r = 1.0 - (s * (1.0 - r));
    g = 1.0 - (s * (1.0 - g));
    b = 1.0 - (s * (1.0 - b));

    // luminosity influence
    r *= l;
    g *= l;
    b *= l;
  }

  void Update(double dt) {
    _interpolate += dt * _change;
    if (_interpolate >= 1.0) {
      _interpolate = 0.0;
      // drastic change
      if (_rng.nextDouble() < _drasticProb) {
        _srcH = _rng.nextDouble();
        _srcS = 1.0 - _rng.nextDouble() * _rng.nextDouble();
        _srcL = 1.0;
      } else {
        _srcH = h;
        _srcS = s;
        _srcL = l;
      }
      _dstH = _rng.nextDouble();
      _dstS = 1.0 - _rng.nextDouble() * _rng.nextDouble();
      _dstL = 1.0;

      _change = _speed * (0.1 + _speedNoise * _rng.nextDouble());
    }
    _ComputeCurrentColor();
    _ComputeRGB();
  }
}

void main(List<String> arguments) {
  Math.Random rng = new Math.Random(1);
  ColorRotator cr = new ColorRotator(rng, 10 * 0.0007, 0.25);
  for (int i = 0; i < 1000; i++) {
    cr.Update(0.030);
    print("\nic ${cr._interpolate} ${cr._change}");
    print("hsl: ${cr.h} ${cr.s} ${cr.l}");
    print("rgb: ${cr.r} ${cr.g} ${cr.b}");
    print("src: ${cr._srcH} ${cr._srcS} ${cr._srcL}");
    print("dst: ${cr._dstH} ${cr._dstS} ${cr._dstL}");
  }
}
