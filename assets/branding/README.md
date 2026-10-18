# Charoite Games splash source

The production splash must use the user's **original animated Charoite Games / CG GIF** unchanged.

The source GIF is not committed on this branch and was not available in the September 28, 2026 handoff chat. Do **not** redraw, regenerate, restyle, stretch, or slow it down.

Expected source characteristics from the handoff:
- approximately 720 × 958
- 48 frames
- approximately 3.84 seconds

For Godot/mobile reliability, extract the original GIF frames losslessly into:

\`assets/branding/cg_splash_frames/\`

Use zero-padded PNG names such as \`cg_000.png\` through \`cg_047.png\`. The startup scene plays the frames at 12.5 FPS (their normal approximate source cadence) and loops cleanly until the total splash gate reaches 5 seconds. The background stays black and the TextureRect preserves aspect ratio.

Re-upload the original GIF before creating these frame files.
