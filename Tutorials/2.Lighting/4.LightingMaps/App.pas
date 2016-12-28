unit App;

{$INCLUDE 'Sample.inc'}

interface

uses
  System.Classes,
  System.UITypes,
  System.SysUtils,
  {$INCLUDE 'OpenGL.inc'}
  Sample.Classes,
  Sample.App;

type
  TLightingMapsApp = class(TApplication)
  private
    FCamera: ICamera;
    FLightingShader: IShader;
    FLampShader: IShader;
    FContainerVAO: IVertexArray;
    FLampVAO: IVertexArray;
    FDiffuseMap: GLuint;
    FSpecularMap: GLuint;
    FUniformViewPos: GLint;
    FUniformLightPosition: GLint;
    FUniformLightAmbient: GLint;
    FUniformLightDiffuse: GLint;
    FUniformLightSpecular: GLint;
    FUniformMaterialShininess: GLint;
    FUniformContainerModel: GLint;
    FUniformContainerView: GLint;
    FUniformContainerProjection: GLint;
    FUniformContainerNormalMatrix: GLint;
    FUniformLampModel: GLint;
    FUniformLampView: GLint;
    FUniformLampProjection: GLint;
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
  Neslib.Stb.Image,
  Neslib.FastMath;

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
  LIGHT_POS: TVector3 = (X: 1.2; Y: 1.0; Z: 2.0);

{ TLightingMapsApp }

procedure TLightingMapsApp.Initialize;
var
  VertexLayout: TVertexLayout;
  Data: TBytes;
  Image: Pointer;
  ImageWidth, ImageHeight, ImageComponents: Integer;
begin
  { Initialize the asset manager }
  TAssets.Initialize;

  { Enable depth testing }
  glEnable(GL_DEPTH_TEST);

  { Create camera }
  FCamera := TCamera.Create(Width, Height, Vector3(0, 0, 3));

  { Build and compile our shader programs }
  FLightingShader := TShader.Create('shaders/lighting_maps.vs', 'shaders/lighting_maps.fs');
  FUniformViewPos := FLightingShader.GetUniformLocation('viewPos');
  FUniformLightPosition := FLightingShader.GetUniformLocation('light.position');
  FUniformLightAmbient := FLightingShader.GetUniformLocation('light.ambient');
  FUniformLightDiffuse := FLightingShader.GetUniformLocation('light.diffuse');
  FUniformLightSpecular := FLightingShader.GetUniformLocation('light.specular');
  FUniformMaterialShininess := FLightingShader.GetUniformLocation('material.shininess');
  FUniformContainerModel := FLightingShader.GetUniformLocation('model');
  FUniformContainerView := FLightingShader.GetUniformLocation('view');
  FUniformContainerProjection := FLightingShader.GetUniformLocation('projection');
  FUniformContainerNormalMatrix := FLightingShader.GetUniformLocation('normalMatrix');

  FLampShader := TShader.Create('shaders/lamp.vs', 'shaders/lamp.fs');
  FUniformLampModel := FLampShader.GetUniformLocation('model');
  FUniformLampView := FLampShader.GetUniformLocation('view');
  FUniformLampProjection := FLampShader.GetUniformLocation('projection');

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

  { Set texture units }
  FLightingShader.Use;
  glUniform1i(FLightingShader.GetUniformLocation('material.diffuse'), 0);
  glUniform1i(FLightingShader.GetUniformLocation('material.specular'), 1);
end;

procedure TLightingMapsApp.KeyDown(const AKey: Integer; const AShift: TShiftState);
begin
  if (AKey = vkEscape) then
    { Terminate app when Esc key is pressed }
    Terminate
  else
    FCamera.ProcessKeyDown(AKey);
end;

procedure TLightingMapsApp.KeyUp(const AKey: Integer; const AShift: TShiftState);
begin
  FCamera.ProcessKeyUp(AKey);
end;

procedure TLightingMapsApp.MouseDown(const AButton: TMouseButton;
  const AShift: TShiftState; const AX, AY: Single);
begin
  FCamera.ProcessMouseDown(AX, AY);
end;

procedure TLightingMapsApp.MouseMove(const AShift: TShiftState; const AX, AY: Single);
begin
  FCamera.ProcessMouseMove(AX, AY);
end;

procedure TLightingMapsApp.MouseUp(const AButton: TMouseButton;
  const AShift: TShiftState; const AX, AY: Single);
begin
  FCamera.ProcessMouseUp;
end;

procedure TLightingMapsApp.MouseWheel(const AShift: TShiftState;
  const AWheelDelta: Integer);
begin
  FCamera.ProcessMouseWheel(AWheelDelta);
end;

procedure TLightingMapsApp.Resize(const AWidth, AHeight: Integer);
begin
  inherited;
  if Assigned(FCamera) then
    FCamera.ViewResized(AWidth, AHeight);
end;

procedure TLightingMapsApp.Shutdown;
begin
  glDeleteTextures(1, @FDiffuseMap);
  glDeleteTextures(1, @FSpecularMap);
end;

procedure TLightingMapsApp.Update(const ADeltaTimeSec, ATotalTimeSec: Double);
var
  Model, View, Projection, Translate, Scale: TMatrix4;
  NormalMatrix: TMatrix3;
begin
  FCamera.HandleInput(ADeltaTimeSec);

  { Define the viewport dimensions }
  glViewport(0, 0, Width, Height);

  { Clear the color and depth buffer }
  glClearColor(0.1, 0.1, 0.1, 1.0);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);

  { Use corresponding shader when setting uniforms/drawing objects }
  FLightingShader.Use;
  glUniform3f(FUniformLightPosition, LIGHT_POS.X, LIGHT_POS.Y, LIGHT_POS.Z);
  glUniform3f(FUniformViewPos, FCamera.Position.X, FCamera.Position.Y, FCamera.Position.Z);

  { Set light properties }
  glUniform3f(FUniformLightAmbient,  0.2, 0.2, 0.2);
  glUniform3f(FUniformLightDiffuse,  0.5, 0.5, 0.5);
  glUniform3f(FUniformLightSpecular, 1.0, 1.0, 1.0);

  { Set material properties }
  glUniform1f(FUniformMaterialShininess, 32.0);

  { Create camera transformation }
  View := FCamera.GetViewMatrix;
  Projection.InitPerspectiveFovRH(Radians(FCamera.Zoom), Width / Height, 0.1, 100.0);

  { Pass matrices to shader }
  glUniformMatrix4fv(FUniformContainerView, 1, GL_FALSE, @View);
  glUniformMatrix4fv(FUniformContainerProjection, 1, GL_FALSE, @Projection);

  { Bind diffuse map }
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, FDiffuseMap);

  { Bind specular map }
  glActiveTexture(GL_TEXTURE1);
  glBindTexture(GL_TEXTURE_2D, FSpecularMap);

  { Create Model matrix and calculate Normal Matrix }
  Model.Init;
  NormalMatrix.Init(Model);
  NormalMatrix := NormalMatrix.Inverse.Transpose;

  { Draw the container }
  glUniformMatrix4fv(FUniformContainerModel, 1, GL_FALSE, @Model);
  glUniformMatrix3fv(FUniformContainerNormalMatrix, 1, GL_FALSE, @NormalMatrix);
  FContainerVAO.Render;

  { Also draw the lamp object }
  FLampShader.Use;
  glUniformMatrix4fv(FUniformLampView, 1, GL_FALSE, @View);
  glUniformMatrix4fv(FUniformLampProjection, 1, GL_FALSE, @Projection);

  Translate.InitTranslation(LIGHT_POS);
  Scale.InitScaling(0.2); { Make it a smaller cube }
  Model := Scale * Translate;
  glUniformMatrix4fv(FUniformLampModel, 1, GL_FALSE, @Model);
  FLampVAO.Render;
end;

end.
