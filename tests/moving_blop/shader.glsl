@header package main
@header import sg "shared:sokol/gfx"
@header import m "../math"

@ctype mat4 m.mat4

@vs vs
layout(binding=0) uniform vs_params {
mat4 mvp;
};

in vec2 position;
in vec4 color0;

out vec4 color;

void main() {
gl_Position = mvp * vec4(position, 0.0, 1.0);
color = color0;
}
@end

@fs fs
in vec4 color;
out vec4 frag_color;

void main() {
frag_color = color;
}
@end

@program blop vs fs
