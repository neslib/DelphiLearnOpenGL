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
  TCameraApp = class(TApplication)
  private
    FCamera: ICamera;
    FShader: IShader;
    FVertexArray: IVertexArray;
    FTexture1: GLuint;
    FTexture2: GLuint;
    FUniformModel: GLint;
    FUniformView: GLint;
    FUniformProjection: GLint;
    FUniformOurTexture1: GLint;
    FUniformOurTexture2: GLint;
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
  { Each vertex consists of a 3-element position and 2-element texture
    coordinate. Each group of 4 vertices defines a side of a cube. }
  VERTICES: array [0..119] of Single = (
    // Positions       // Texture Coords
    -0.5, -0.5, -0.5,  0.0, 0.0,
     0.5, -0.5, -0.5,  1.0, 0.0,
     0.5,  0.5, -0.5,  1.0, 1.0,
    -0.5,  0.5, -0.5,  0.0, 1.0,

    -0.5, -0.5,  0.5,  0.0, 0.0,
     0.5, -0.5,  0.5,  1.0, 0.0,
     0.5,  0.5,  0.5,  1.0, 1.0,
    -0.5,  0.5,  0.5,  0.0, 1.0,

    -0.5,  0.5,  0.5,  1.0, 0.0,
    -0.5,  0.5, -0.5,  1.0, 1.0,
    -0.5, -0.5, -0.5,  0.0, 1.0,
    -0.5, -0.5,  0.5,  0.0, 0.0,

     0.5,  0.5,  0.5,  1.0, 0.0,
     0.5,  0.5, -0.5,  1.0, 1.0,
     0.5, -0.5, -0.5,  0.0, 1.0,
     0.5, -0.5,  0.5,  0.0, 0.0,

    -0.5, -0.5, -0.5,  0.0, 1.0,
     0.5, -0.5, -0.5,  1.0, 1.0,
     0.5, -0.5,  0.5,  1.0, 0.0,
    -0.5, -0.5,  0.5,  0.0, 0.0,

    -0.5,  0.5, -0.5,  0.0, 1.0,
     0.5,  0.5, -0.5,  1.0, 1.0,
     0.5,  0.5,  0.5,  1.0, 0.0,
    -0.5,  0.5,  0.5,  0.0, 0.0);

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
  { World space positions of our cubes }
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

{ TCameraApp }

procedure TCameraApp.Initialize;
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

  { Build and compile our shader program }
  FShader := TShader.Create('shaders/coordinate_systems.vs', 'shaders/coordinate_systems.fs');
  FUniformModel := FShader.GetUniformLocation('model');
  FUniformView := FShader.GetUniformLocation('view');
  FUniformProjection := FShader.GetUniformLocation('projection');
  FUniformOurTexture1 := FShader.GetUniformLocation('ourTexture1');
  FUniformOurTexture2 := FShader.GetUniformLocation('ourTexture2');

  { Define layout of the attributes in the shader program. }
  VertexLayout.Start(FShader)
    .Add('position', 3)
    .Add('texCoord', 2);

  { Create the vertex array }
  FVertexArray := TVertexArray.Create(VertexLayout,
    VERTICES, SizeOf(VERTICES), INDICES);

  { Texture 1
    ========= }
  glGenTextures(1, @FTexture1);
  glBindTexture(GL_TEXTURE_2D, FTexture1);
  { All upcoming GL_TEXTURE_2D operations now have effect on our texture object }

  { Set our texture parameters }
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);

  { Set texture filtering }
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

  { Load, create texture and generate mipmaps }
  Data := TAssets.Load('textures/container.jpg');
  Assert(Assigned(Data));
  Image := stbi_load_from_memory(Data, Length(Data), ImageWidth, ImageHeight, ImageComponents, 3);
  Assert(Assigned(Image));
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, ImageWidth, ImageHeight, 0, GL_RGB, GL_UNSIGNED_BYTE, Image);
  glGenerateMipmap(GL_TEXTURE_2D);
  stbi_image_free(Image);
  glBindTexture(GL_TEXTURE_2D, 0);
  glErrorCheck;

  { Texture 2
    ========= }
  glGenTextures(1, @FTexture2);
  glBindTexture(GL_TEXTURE_2D, FTexture2);
  { All upcoming GL_TEXTURE_2D operations now have effect on our texture object }

  { Set our texture parameters }
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);

  { Set texture filtering }
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

  { Load, create texture and generate mipmaps }
  Data := TAssets.Load('textures/awesomeface.png');
  Assert(Assigned(Data));
  Image := stbi_load_from_memory(Data, Length(Data), ImageWidth, ImageHeight, ImageComponents, 3);
  Assert(Assigned(Image));
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, ImageWidth, ImageHeight, 0, GL_RGB, GL_UNSIGNED_BYTE, Image);
  glGenerateMipmap(GL_TEXTURE_2D);
  stbi_image_free(Image);
  glBindTexture(GL_TEXTURE_2D, 0);
  glErrorCheck;
end;

procedure TCameraApp.KeyDown(const AKey: Integer; const AShift: TShiftState);
begin
  if (AKey = vkEscape) then
    { Terminate app when Esc key is pressed }
    Terminate
  else
    FCamera.ProcessKeyDown(AKey);
end;

procedure TCameraApp.KeyUp(const AKey: Integer; const AShift: TShiftState);
begin
  FCamera.ProcessKeyUp(AKey);
end;

procedure TCameraApp.MouseDown(const AButton: TMouseButton;
  const AShift: TShiftState; const AX, AY: Single);
begin
  FCamera.ProcessMouseDown(AX, AY);
end;

procedure TCameraApp.MouseMove(const AShift: TShiftState; const AX, AY: Single);
begin
  FCamera.ProcessMouseMove(AX, AY);
end;

procedure TCameraApp.MouseUp(const AButton: TMouseButton;
  const AShift: TShiftState; const AX, AY: Single);
begin
  FCamera.ProcessMouseUp;
end;

procedure TCameraApp.MouseWheel(const AShift: TShiftState;
  const AWheelDelta: Integer);
begin
  FCamera.ProcessMouseWheel(AWheelDelta);
end;

procedure TCameraApp.Resize(const AWidth, AHeight: Integer);
begin
  inherited;
  if Assigned(FCamera) then
    FCamera.ViewResized(AWidth, AHeight);
end;

procedure TCameraApp.Shutdown;
begin
  glDeleteTextures(1, @FTexture1);
  glDeleteTextures(1, @FTexture2);
end;

procedure TCameraApp.Update(const ADeltaTimeSec, ATotalTimeSec: Double);
var
  Model, View, Projection, Rotate: TMatrix4;
  I: Integer;
begin
  { Handle any input that happened since the last frame }
  FCamera.HandleInput(ADeltaTimeSec);

  { Define the viewport dimensions }
  glViewport(0, 0, Width, Height);

  { Clear the color and depth buffer }
  glClearColor(0.2, 0.3, 0.3, 1.0);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);

  FShader.Use;

  { Bind Textures using texture units }
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, FTexture1);
  glUniform1i(FUniformOurTexture1, 0);
  glActiveTexture(GL_TEXTURE1);
  glBindTexture(GL_TEXTURE_2D, FTexture2);
  glUniform1i(FUniformOurTexture2, 1);

  { Create camera transformation }
  View := FCamera.GetViewMatrix;
  Projection.InitPerspectiveFovRH(Radians(FCamera.Zoom), Width / Height, 0.1, 1000);

  { Pass matrices to shader }
  glUniformMatrix4fv(FUniformView, 1, GL_FALSE, @View);
  glUniformMatrix4fv(FUniformProjection, 1, GL_FALSE, @Projection);

  { Draw the cubes. Since we draw the same cube (vertex array) multiple times,
    it is more efficient to render them inside a BeginRender/EndRender block. }
  FVertexArray.BeginRender;
  for I := 0 to Length(CUBE_POSITIONS) - 1 do
  begin
    { Calculate the model matrix for each object and pass it to shader before
      drawing }
    Model.InitTranslation(CUBE_POSITIONS[I]);
    Rotate.InitRotation(Vector3(1, 0.3, 0.5), Radians(20 * I));
    Model := Rotate * Model;
    glUniformMatrix4fv(FUniformModel, 1, GL_FALSE, @Model);
    FVertexArray.Render;
  end;
  FVertexArray.EndRender;
end;

end.
