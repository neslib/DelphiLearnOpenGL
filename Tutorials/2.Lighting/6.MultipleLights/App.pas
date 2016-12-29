unit App;

{$INCLUDE 'Sample.inc'}

interface

uses
  System.Classes,
  System.UITypes,
  System.SysUtils,
  {$INCLUDE 'OpenGL.inc'}
  Neslib.FastMath,
  Sample.Classes,
  Sample.App;

type
  { Combines all uniforms for Model, View and Projection matrices }
  TUniformMVP = record
  public
    Model: GLint;
    View: GLint;
    Projection: GLint;
  public
    { Retrieves the uniform locations from the given shader }
    procedure Init(const AShader: IShader);

    { Sets the uniform values for the currently active shader }
    procedure Apply(const AModel: TMatrix4); overload;
    procedure Apply(const AView, AProjection: TMatrix4); overload;
  end;

type
  { Combines all uniforms for a material.
    Matches the Material struct in the fragment shader. }
  TUniformMaterial = record
  public
    Diffuse: GLint;
    Specular: GLint;
    Shininess: GLint;
  public
    { Retrieves the uniform locations from the given shader }
    procedure Init(const AShader: IShader);

    { Sets the uniform values for the currently active shader }
    procedure Apply(const AShininess: Single);
  end;

type
  { Combines all uniforms for a directional light.
    Matches the DirLight struct in the fragment shader. }
  TUniformDirLight = record
  public
    Direction: GLint;

    Ambient: GLint;
    Diffuse: GLint;
    Specular: GLint;
  public
    { Retrieves the uniform locations from the given shader }
    procedure Init(const AShader: IShader);

    { Sets the uniform values for the currently active shader }
    procedure Apply(const ADirection, AAmbient, ADiffuse, ASpecular: TVector3);
  end;

type
  { Combines all uniforms for a point light.
    Matches the PointLight struct in the fragment shader. }
  TUniformPointLight = record
  public
    Position: GLint;

    Constant: GLint;
    Linear: GLint;
    Quadratic: GLint;

    Ambient: GLint;
    Diffuse: GLint;
    Specular: GLint;
  public
    { Retrieves the uniform locations from the given shader }
    procedure Init(const AShader: IShader; const ALightIndex: Integer);

    { Sets the uniform values for the currently active shader }
    procedure Apply(const APosition, AAmbient, ADiffuse, ASpecular: TVector3;
      const AConstant, ALinear, AQuadratic: Single);
  end;

type
  { Combines all uniforms for a spot light.
    Matches the SpotLight struct in the fragment shader. }
  TUniformSpotLight = record
  public
    Position: GLint;
    Direction: GLint;
    CutOff: GLint;
    OuterCutOff: GLint;

    Constant: GLint;
    Linear: GLint;
    Quadratic: GLint;

    Ambient: GLint;
    Diffuse: GLint;
    Specular: GLint;
  public
    { Retrieves the uniform locations from the given shader }
    procedure Init(const AShader: IShader);

    { Sets the uniform values for the currently active shader }
    procedure Apply(const APosition, ADirection, AAmbient, ADiffuse,
      ASpecular: TVector3; const AConstant, ALinear, AQuadratic, ACutOff,
      AOuterCutOff: Single);
  end;

const
  NUM_POINT_LIGHTS = 4;

type
  TMultipleLightsApp = class(TApplication)
  private
    FCamera: ICamera;
    FLightingShader: IShader;
    FLampShader: IShader;
    FContainerVAO: IVertexArray;
    FLampVAO: IVertexArray;
    FUniformMVP: TUniformMVP;
    FUniformNormalMatrix: GLint;
    FUniformViewPos: GLint;
    FUniformDirLight: TUniformDirLight;
    FUniformPointLight: array [0..NUM_POINT_LIGHTS - 1] of TUniformPointLight;
    FUniformSpotLight: TUniformSpotLight;
    FUniformMaterial: TUniformMaterial;
    FUniformLampMVP: TUniformMVP;
    FDiffuseMap: GLuint;
    FSpecularMap: GLuint;
  public
    procedure Initialize; override;
    procedure Update(const ADeltaTimeSec, ATotalTimeSec: Double); override;
    procedure Shutdown; override;
    procedure Resize(const AWidth, AHeight: Integer); override;
  public
    procedure KeyDown(const AKey: Integer; const AShift: TShiftState); override;
    procedure KeyUp(const AKey: Integer; const AShift: TShiftState); override;
    procedure MouseDown(const AButton: TMouseButton; const AShift: TShiftState;
      const AX, AY: Single); override;
    procedure MouseMove(const AShift: TShiftState; const AX, AY: Single); override;
    procedure MouseUp(const AButton: TMouseButton; const AShift: TShiftState;
      const AX, AY: Single); override;
    procedure MouseWheel(const AShift: TShiftState; const AWheelDelta: Integer); override;
  end;

implementation

uses
  Neslib.Stb.Image;

const
  { Each container vertex consists of a 3-element position and a 3-element
    normal and a 2-element texture coordinate.
    Each group of 4 vertices defines a side of a cube. }
  CONTAINER_VERTICES: array [0..191] of Single = (
    // Positions      // Normals         // Texture Coords
    -0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  0.0, 0.0,
     0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  1.0, 0.0,
     0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  1.0, 1.0,
    -0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  0.0, 1.0,

    -0.5, -0.5,  0.5,  0.0,  0.0,  1.0,  0.0, 0.0,
     0.5, -0.5,  0.5,  0.0,  0.0,  1.0,  1.0, 0.0,
     0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  1.0, 1.0,
    -0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  0.0, 1.0,

    -0.5,  0.5,  0.5, -1.0,  0.0,  0.0,  1.0, 0.0,
    -0.5,  0.5, -0.5, -1.0,  0.0,  0.0,  1.0, 1.0,
    -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,  0.0, 1.0,
    -0.5, -0.5,  0.5, -1.0,  0.0,  0.0,  0.0, 0.0,

     0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  1.0, 0.0,
     0.5,  0.5, -0.5,  1.0,  0.0,  0.0,  1.0, 1.0,
     0.5, -0.5, -0.5,  1.0,  0.0,  0.0,  0.0, 1.0,
     0.5, -0.5,  0.5,  1.0,  0.0,  0.0,  0.0, 0.0,

    -0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  0.0, 1.0,
     0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  1.0, 1.0,
     0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  1.0, 0.0,
    -0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  0.0, 0.0,

    -0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  0.0, 1.0,
     0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  1.0, 1.0,
     0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  1.0, 0.0,
    -0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  0.0, 0.0);

const
  { Each lamp vertex consists of a 3-element position.
    Each group of 4 vertices defines a side of a cube. }
  LAMP_VERTICES: array [0..71] of Single = (
    // Positions
    -0.5, -0.5, -0.5,
     0.5, -0.5, -0.5,
     0.5,  0.5, -0.5,
    -0.5,  0.5, -0.5,

    -0.5, -0.5,  0.5,
     0.5, -0.5,  0.5,
     0.5,  0.5,  0.5,
    -0.5,  0.5,  0.5,

    -0.5,  0.5,  0.5,
    -0.5,  0.5, -0.5,
    -0.5, -0.5, -0.5,
    -0.5, -0.5,  0.5,

     0.5,  0.5,  0.5,
     0.5,  0.5, -0.5,
     0.5, -0.5, -0.5,
     0.5, -0.5,  0.5,

    -0.5, -0.5, -0.5,
     0.5, -0.5, -0.5,
     0.5, -0.5,  0.5,
    -0.5, -0.5,  0.5,

    -0.5,  0.5, -0.5,
     0.5,  0.5, -0.5,
     0.5,  0.5,  0.5,
    -0.5,  0.5,  0.5);

const
  { The indices define 2 triangles per cube face, 6 faces total }
  INDICES: array [0..35] of UInt16 = (
     0,  1,  2,   2,  3,  0,
     4,  5,  6,   6,  7,  4,
     8,  9, 10,  10, 11,  8,
    12, 13, 14,  14, 15, 12,
    16, 17, 18,  18, 19, 16,
    20, 21, 22,  22, 23, 20);

const
  // Positions of all containers
  CUBE_POSITIONS: array [0..9] of TVector3 = (
    (X:  0.0; Y:  0.0; Z:   0.0),
    (X:  2.0; Y:  5.0; Z: -15.0),
    (X: -1.5; Y: -2.2; Z:  -2.5),
    (X: -3.8; Y: -2.0; Z: -12.3),
    (X:  2.4; Y: -0.4; Z:  -3.5),
    (X: -1.7; Y:  3.0; Z:  -7.5),
    (X:  1.3; Y: -2.0; Z:  -2.5),
    (X:  1.5; Y:  2.0; Z:  -2.5),
    (X:  1.5; Y:  0.2; Z:  -1.5),
    (X: -1.3; Y:  1.0; Z:  -1.5));

const
  // Positions of the point lights
  POINT_LIGHT_POSITIONS: array [0..NUM_POINT_LIGHTS - 1] of TVector3 = (
    (X:  0.7; Y:  0.2; Z:   2.0),
    (X:  2.3; Y: -3.3; Z:  -4.0),
    (X: -4.0; Y:  2.0; Z: -12.0),
    (X:  0.0; Y:  0.0; Z:  -3.0));

{ TMultipleLightsApp }

procedure TMultipleLightsApp.Initialize;
var
  VertexLayout: TVertexLayout;
  Data: TBytes;
  Image: Pointer;
  I, ImageWidth, ImageHeight, ImageComponents: Integer;
begin
  { Initialize the asset manager }
  TAssets.Initialize;

  { Enable depth testing }
  glEnable(GL_DEPTH_TEST);

  { Create camera }
  FCamera := TCamera.Create(Width, Height, Vector3(0, 0, 3));

  { Build and compile our shader programs }
  FLightingShader := TShader.Create('shaders/multiple_lights.vs', 'shaders/multiple_lights.fs');
  FUniformMVP.Init(FLightingShader);
  FUniformNormalMatrix := FLightingShader.GetUniformLocation('normalMatrix');
  FUniformViewPos := FLightingShader.GetUniformLocation('viewPos');
  FUniformDirLight.Init(FLightingShader);
  for I := 0 to NUM_POINT_LIGHTS - 1 do
    FUniformPointLight[I].Init(FLightingShader, I);
  FUniformSpotLight.Init(FLightingShader);
  FUniformMaterial.Init(FLightingShader);

  FLampShader := TShader.Create('shaders/lamp.vs', 'shaders/lamp.fs');
  FUniformLampMVP.Init(FLampShader);

  { Define layout of the attributes in the Lighting shader }
  VertexLayout.Start(FLightingShader)
    .Add('position', 3)
    .Add('normal', 3)
    .Add('texCoords', 2);

  { Create the vertex array for the container. }
  FContainerVAO := TVertexArray.Create(VertexLayout,
    CONTAINER_VERTICES, SizeOf(CONTAINER_VERTICES), INDICES);

  { Define layout of the attributes in the Lamp shader }
  VertexLayout.Start(FLampShader)
    .Add('position', 3);

  { Create the vertex array for the lamp. }
  FLampVAO := TVertexArray.Create(VertexLayout,
    LAMP_VERTICES, SizeOf(LAMP_VERTICES), INDICES);

  { Load textures }

  { Diffuse Map
    =========== }
  glGenTextures(1, @FDiffuseMap);
  glBindTexture(GL_TEXTURE_2D, FDiffuseMap);

  { Set our texture parameters }
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

  { Set texture filtering }
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

  { Load, create texture and generate mipmaps }
  Data := TAssets.Load('textures/container2.png');
  Assert(Assigned(Data));
  Image := stbi_load_from_memory(Data, Length(Data), ImageWidth, ImageHeight, ImageComponents, 3);
  Assert(Assigned(Image));
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, ImageWidth, ImageHeight, 0, GL_RGB, GL_UNSIGNED_BYTE, Image);
  stbi_image_free(Image);
  glBindTexture(GL_TEXTURE_2D, 0);
  glErrorCheck;

  { Specular Map
    ============ }
  glGenTextures(1, @FSpecularMap);
  glBindTexture(GL_TEXTURE_2D, FSpecularMap);
  { All upcoming GL_TEXTURE_2D operations now have effect on our texture object }

  { Set our texture parameters }
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

  { Set texture filtering }
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

  { Load, create texture and generate mipmaps }
  Data := TAssets.Load('textures/container2_specular.png');
  Assert(Assigned(Data));
  Image := stbi_load_from_memory(Data, Length(Data), ImageWidth, ImageHeight, ImageComponents, 3);
  Assert(Assigned(Image));
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, ImageWidth, ImageHeight, 0, GL_RGB, GL_UNSIGNED_BYTE, Image);
  stbi_image_free(Image);
  glBindTexture(GL_TEXTURE_2D, 0);
  glErrorCheck;
end;

procedure TMultipleLightsApp.KeyDown(const AKey: Integer; const AShift: TShiftState);
begin
  if (AKey = vkEscape) then
    { Terminate app when Esc key is pressed }
    Terminate
  else
    FCamera.ProcessKeyDown(AKey);
end;

procedure TMultipleLightsApp.KeyUp(const AKey: Integer; const AShift: TShiftState);
begin
  FCamera.ProcessKeyUp(AKey);
end;

procedure TMultipleLightsApp.MouseDown(const AButton: TMouseButton;
  const AShift: TShiftState; const AX, AY: Single);
begin
  FCamera.ProcessMouseDown(AX, AY);
end;

procedure TMultipleLightsApp.MouseMove(const AShift: TShiftState; const AX, AY: Single);
begin
  FCamera.ProcessMouseMove(AX, AY);
end;

procedure TMultipleLightsApp.MouseUp(const AButton: TMouseButton;
  const AShift: TShiftState; const AX, AY: Single);
begin
  FCamera.ProcessMouseUp;
end;

procedure TMultipleLightsApp.MouseWheel(const AShift: TShiftState;
  const AWheelDelta: Integer);
begin
  FCamera.ProcessMouseWheel(AWheelDelta);
end;

procedure TMultipleLightsApp.Resize(const AWidth, AHeight: Integer);
begin
  inherited;
  if Assigned(FCamera) then
    FCamera.ViewResized(AWidth, AHeight);
end;

procedure TMultipleLightsApp.Shutdown;
begin
  glDeleteTextures(1, @FDiffuseMap);
  glDeleteTextures(1, @FSpecularMap);
end;

procedure TMultipleLightsApp.Update(const ADeltaTimeSec, ATotalTimeSec: Double);
var
  Model, View, Projection, Translate, Rotate, Scale: TMatrix4;
  NormalMatrix: TMatrix3;
  I: Integer;
begin
  FCamera.HandleInput(ADeltaTimeSec);

  { Define the viewport dimensions }
  glViewport(0, 0, Width, Height);

  { Clear the color and depth buffer }
  glClearColor(0.1, 0.1, 0.1, 1.0);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);

  { Use corresponding shader when setting uniforms/drawing objects }
  FLightingShader.Use;
  glUniform3f(FUniformViewPos, FCamera.Position.X, FCamera.Position.Y, FCamera.Position.Z);

  { Set material properties }
  FUniformMaterial.Apply(32.0);

  { Here we set all the uniforms for the lights we have.
    This can be done using a more efficient uniform approach by using
    'Uniform buffer objects', but that is something we discuss in the
    'Advanced GLSL' tutorial. }
  FUniformDirLight.Apply(
    Vector3(-0.2, -1.0, -0.3), // Direction
    Vector3(0.05, 0.05, 0.05), // Ambient
    Vector3(0.4, 0.4, 0.4),    // Diffuse
    Vector3(0.5, 0.5, 0.5));   // Specular

  for I := 0 to NUM_POINT_LIGHTS - 1 do
    FUniformPointLight[I].Apply(
      POINT_LIGHT_POSITIONS[I],  // Position
      Vector3(0.05, 0.05, 0.05), // Ambient
      Vector3(0.8, 0.8, 0.8),    // Diffuse
      Vector3(1.0, 1.0, 1.0),    // Specular
      1.0, 0.09, 0.032);         // Constant, Linear, Quadratic

  FUniformSpotLight.Apply(
    FCamera.Position,       // Position
    FCamera.Front,          // Direction
    Vector3(0.0, 0.0, 0.0), // Ambient
    Vector3(1.0, 1.0, 1.0), // Diffuse
    Vector3(1.0, 1.0, 1.0), // Specular
    1.0, 0.09, 0.032,       // Constant, Linear, Quadratic
    Cos(Radians(12.5)),     // CutOff
    Cos(Radians(15.0)));    // OuterCutOff

  { Create camera transformation }
  View := FCamera.GetViewMatrix;
  Projection.InitPerspectiveFovRH(Radians(FCamera.Zoom), Width / Height, 0.1, 100.0);

  { Pass matrices to shader }
  FUniformMVP.Apply(View, Projection);

  { Bind diffuse map }
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, FDiffuseMap);

  { Bind specular map }
  glActiveTexture(GL_TEXTURE1);
  glBindTexture(GL_TEXTURE_2D, FSpecularMap);

  { Draw 10 containers with the same VAO and VBO information;
    only their world space coordinates differ }
  FContainerVAO.BeginRender;
  for I := 0 to Length(CUBE_POSITIONS) - 1 do
  begin
    { Create Model matrix }
    Translate.InitTranslation(CUBE_POSITIONS[I]);
    Rotate.InitRotation(Vector3(1.0, 0.3, 0.5), Radians(20.0 * I));
    Model := Rotate * Translate;

    { Calculate Normal matrix }
    NormalMatrix.Init(Model);
    NormalMatrix := NormalMatrix.Inverse.Transpose;

    { Draw the container }
    FUniformMVP.Apply(Model);
    glUniformMatrix3fv(FUniformNormalMatrix, 1, GL_FALSE, @NormalMatrix);
    FContainerVAO.Render;
  end;
  FContainerVAO.EndRender;

  { Also draw the lamp objects, again binding the appropriate shader }
  FLampShader.Use;
  FUniformLampMVP.Apply(View, Projection);

  { We now draw as many light bulbs as we have point lights. }
  FLampVAO.BeginRender;
  for I := 0 to NUM_POINT_LIGHTS - 1 do
  begin
    Translate.InitTranslation(POINT_LIGHT_POSITIONS[I]);
    Scale.InitScaling(0.2);
    Model := Scale * Translate;
    FUniformLampMVP.Apply(Model);
    FLampVAO.Render;
  end;
  FLampVAO.EndRender;
end;

{ TUniformMVP }

procedure TUniformMVP.Apply(const AView, AProjection: TMatrix4);
begin
  glUniformMatrix4fv(View, 1, GL_FALSE, @AView);
  glUniformMatrix4fv(Projection, 1, GL_FALSE, @AProjection);
end;

procedure TUniformMVP.Apply(const AModel: TMatrix4);
begin
  glUniformMatrix4fv(Model, 1, GL_FALSE, @AModel);
end;

procedure TUniformMVP.Init(const AShader: IShader);
begin
  Model := AShader.GetUniformLocation('model');
  View := AShader.GetUniformLocation('view');
  Projection := AShader.GetUniformLocation('projection');
end;

{ TUniformMaterial }

procedure TUniformMaterial.Apply(const AShininess: Single);
begin
  { Set texture units }
  glUniform1i(Diffuse, 0);
  glUniform1i(Specular, 1);

  { Set properties }
  glUniform1f(Shininess, AShininess);
end;

procedure TUniformMaterial.Init(const AShader: IShader);
begin
  Diffuse := AShader.GetUniformLocation('material.diffuse');
  Specular := AShader.GetUniformLocation('material.specular');
  Shininess := AShader.GetUniformLocation('material.shininess');
end;

{ TUniformDirLight }

procedure TUniformDirLight.Apply(const ADirection, AAmbient, ADiffuse,
  ASpecular: TVector3);
begin
  glUniform3fv(Direction, 1, @ADirection);
  glUniform3fv(Ambient, 1, @AAmbient);
  glUniform3fv(Diffuse, 1, @ADiffuse);
  glUniform3fv(Specular, 1, @ASpecular);
end;

procedure TUniformDirLight.Init(const AShader: IShader);
begin
  Direction := AShader.GetUniformLocation('dirLight.direction');
  Ambient := AShader.GetUniformLocation('dirLight.ambient');
  Diffuse := AShader.GetUniformLocation('dirLight.diffuse');
  Specular := AShader.GetUniformLocation('dirLight.specular');
end;

{ TUniformPointLight }

procedure TUniformPointLight.Apply(const APosition, AAmbient, ADiffuse,
  ASpecular: TVector3; const AConstant, ALinear, AQuadratic: Single);
begin
  glUniform3fv(Position, 1, @APosition);
  glUniform3fv(Ambient, 1, @AAmbient);
  glUniform3fv(Diffuse, 1, @ADiffuse);
  glUniform3fv(Specular, 1, @ASpecular);
  glUniform1f(Constant, AConstant);
  glUniform1f(Linear, ALinear);
  glUniform1f(Quadratic, AQuadratic);
end;

procedure TUniformPointLight.Init(const AShader: IShader;
  const ALightIndex: Integer);
begin
  Position := AShader.GetUniformLocationUnicode(Format('pointLights[%d].position', [ALightIndex]));
  Constant := AShader.GetUniformLocationUnicode(Format('pointLights[%d].constant', [ALightIndex]));
  Linear := AShader.GetUniformLocationUnicode(Format('pointLights[%d].linear', [ALightIndex]));
  Quadratic := AShader.GetUniformLocationUnicode(Format('pointLights[%d].quadratic', [ALightIndex]));
  Ambient := AShader.GetUniformLocationUnicode(Format('pointLights[%d].ambient', [ALightIndex]));
  Diffuse := AShader.GetUniformLocationUnicode(Format('pointLights[%d].diffuse', [ALightIndex]));
  Specular := AShader.GetUniformLocationUnicode(Format('pointLights[%d].specular', [ALightIndex]));
end;

{ TUniformSpotLight }

procedure TUniformSpotLight.Apply(const APosition, ADirection, AAmbient,
  ADiffuse, ASpecular: TVector3; const AConstant, ALinear, AQuadratic, ACutOff,
  AOuterCutOff: Single);
begin
  glUniform3fv(Position, 1, @APosition);
  glUniform3fv(Direction, 1, @ADirection);
  glUniform3fv(Ambient, 1, @AAmbient);
  glUniform3fv(Diffuse, 1, @ADiffuse);
  glUniform3fv(Specular, 1, @ASpecular);
  glUniform1f(Constant, AConstant);
  glUniform1f(Linear, ALinear);
  glUniform1f(Quadratic, AQuadratic);
  glUniform1f(CutOff, ACutOff);
  glUniform1f(OuterCutOff, AOuterCutOff);
end;

procedure TUniformSpotLight.Init(const AShader: IShader);
begin
  Position := AShader.GetUniformLocation('spotLight.position');
  Direction := AShader.GetUniformLocation('spotLight.direction');
  CutOff := AShader.GetUniformLocation('spotLight.cutOff');
  OuterCutOff := AShader.GetUniformLocation('spotLight.outerCutOff');
  Constant := AShader.GetUniformLocation('spotLight.constant');
  Linear := AShader.GetUniformLocation('spotLight.linear');
  Quadratic := AShader.GetUniformLocation('spotLight.quadratic');
  Ambient := AShader.GetUniformLocation('spotLight.ambient');
  Diffuse := AShader.GetUniformLocation('spotLight.diffuse');
  Specular := AShader.GetUniformLocation('spotLight.specular');
end;

end.
