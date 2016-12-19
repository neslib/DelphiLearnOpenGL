# Learn OpenGL(ES) with Delphi

This is the Delphi version of Joey de Vries's excellent set of [Learn OpenGL](https://learnopengl.com/) tutorials. Those tutorials focus on **modern** desktop OpenGL using C and C++.

This version differs from Joey's version in a couple of areas though:
* It uses [Delphi](https://www.embarcadero.com/products/delphi) as the programming language.
* It focuses primarily on a subset of OpenGL called OpenGL ES. In particular OpenGL ES 2.0.
* As a result, the tutorials are cross-platform and work on Windows, macOS, iOS and Android.
* For setting up the render window and handling user input, Joey's version uses the [GLFW](http://www.glfw.org/) utility library. However, since GLFW is not supported for iOS and Android, we cannot use it. (If you are interested in Windows and macOS only, you can download my [GLFW Language Bindings for Delphi](https://github.com/neslib/DelphiGlfw)). I could have used another utility library like [SDL2](https://www.libsdl.org/), but decided to write all platform-specific code in Delphi instead, which can be a good learning experience in itself.
* For 2D and 3D math, Joey's version uses the [GLM](http://glm.g-truc.net/) library. For Delphi, we could use Delphi's built-in math functions (like the `System.Math.Vectors` unit). However, I use this opportunity to plug my [FastMath](https://github.com/neslib/FastMath) library, which API is very similar to Delphi's, but is **much much** faster. Since you probably want to use OpenGL for high performance graphics, you should use a high performance math library as well.

## Delphi Requirements

These tutorials require Delphi 10.1 Berlin or later. The reason for this is that Delphi Berlin re-introduced 8-bit strings on mobile platforms (only of type `RawByteString` though). This makes it easier and faster to interoperate with OpenGL and other C-API's that use 8-bit strings.

If you use an older version of Delphi, you can still use it when you target Windows and/or macOS only. If you want the tutorials to work on mobile platforms as well with an older Delphi version, then you will have to modify the code everywhere RawByteStrings are used and perform your own Unicode-to-MarshaledAString marshalling.

## OpenGL ES

All tutorials uses the OpenGL ES 2.0 subset of OpenGL, unless noted otherwise. The ES suffix stands for Embedded Systems. This flavor of OpenGL is supported on iOS and Android and also forms the basis for WebGL (meaning that these tutorials can be translated to a web-browser as well).

For the most part, as long as you stick to the OpenGL ES subset, your app will work on desktop platforms (Windows and macOS) as well. This makes writing cross-platform OpenGL apps much easier.

## Platform-Specific Glue Code

Setting up the application and handling user input requires platform-specific code. We could use Delphi's FireMonkey framework to handle this for us. However, FireMonkey is not well suited for high-performance apps and games. In addition, FireMonkey on Windows uses DirectX for 3D graphics and not OpenGL.

So, these tutorials don't use FireMonkey at all, but instead handle app setup and input handling manually. More about this is in the "Creating an OpenGL App" tutorial.

## Dependencies

Besides Delphi, these tutorials have a couple of dependencies. These can be downloaded and used for free and don't require any installation into system directories:

* [FastMath](https://github.com/neslib/FastMath) is used for all vector and matrix math.
* [DelphiStb](https://github.com/neslib/DelphiStb) are Delphi header translations for some awesome public domain C [stb libraries](https://github.com/nothings/stb). We mostly use the `Neslib.Stb.Image` unit for cross-platform loading of image files (since we cannot use FireMonkey for that).

Put the FastMath and DelphiStb libraries at the same directory level as these tutorials. Otherwise, the Delphi projects cannot find them. For example, a directory structure like this:

* C:\Development
  * \Neslib
    * \DelphiLearnOpenGL
    * \DelphiStb
    * \FastMath

## Structure

Learn OpenGL(ES) with Delphi is broken down into a number of general subjects. Each subject contains several sections that each explain different concepts in large detail. Each of the subjects can be found in the Tutorial Index below and each tutorial links to the previous and next tutorials. The subjects are taught in a linear fashion (so it is advised to start from the top to the bottom, unless otherwise instructed) where each page explains the background theory and the practical aspects.

To make the tutorials easier to follow and give them some added structure the site contains blockquotes and code blocks.

### Blockquotes

> :information_source: Information blockquotes encompasses some notes or useful features/hints about OpenGL or the subject at hand.


> :warning: Warning blockquotes will contain warnings or other features you have to be extra careful with.

> :exclamation:`Windows` Blockquotes starting with an exclamation followed by one or more platforms (`Windows`, `macOS`, `iOS` or `Android`) contain notes specific to those platforms,. 

> :link: Link blockquotes link to the corresponding code in the GitHub repository.

### Code
You will find plenty of small pieces of code are located in boxes with syntax-highlighted code as you can see below:

```Delphi
// This box contains code
```
    
Since these provide only snippets of code, wherever necessary I will provide a link to the entire source code required for a given subject.

## <a name="Contents"></a>Tutorials Index

* Getting Started
  * [OpenGL (ES)](Documentation/1.GettingStarted/1.0a.OpenGL.md)
  * [Creating an OpenGL App](Documentation/1.GettingStarted/1.0b.CreateApp.md)
  * [1.1 Hello Window](Documentation/1.GettingStarted/1.1.HelloWindow.md)
  * 1.2 Hello Triangle
  * 1.3 Shaders
  * 1.4 Textures
  * 1.5 Transformations
  * 1.6 Coordinate Systems
  * 1.7 Camera
  * Review
* Lighting
  * Colors
  * Basic Lighting
  * Materials
  * Lighting Maps
  * Light Casters
  * Multiple Lights
  * Review
* Model Loading
  * Assimp
  * Mesh
  * Model
* Advanced OpenGL
  * Depth Testing
  * Stencil Testing
  * Blending
  * Face Culling
  * Framebuffers
  * Cubemaps
  * Advanced Data
  * Advanced GLSL
  * Geometry Shader
  * Instancing
  * Anti Aliasing
* Advanced Lighting
  * Advanced Lighting
  * Gamma Correction
  * Shadows
    * Shadow Mapping
    * Point Shadows
    * CSM
  * Normal Mapping
  * Parallax Mapping
  * HDR
  * Bloom
  * Deferred Shading
  * SSAO
* PBR
  * Theory
  * Lighting
  * IBL
    * Diffuse Irradiance
    * Specular IBL
* In Practive
  * Debugging
  * Text Rendering
  * 2D Game
    * Breakout
    * Setting Up
    * Rendering Sprites
    * Levels
    * Collisions
      * Ball
      * Collision Detection
      * Collision Resolution
    * Particles
    * Postprocessing
    * Powerups
    * Audio
    * Render Text
    * Final Thoughts                 