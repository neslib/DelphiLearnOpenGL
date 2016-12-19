unit App;

{$INCLUDE 'Sample.inc'}

interface

uses
  System.Classes,
  System.SysUtils,
  {$INCLUDE 'OpenGL.inc'}
  Sample.Classes,
  Sample.App;

type
  TTransformations = class(TApplication)
  private
    FShader: IShader;
    FVertexArray: IVertexArray;
    FTexture1: GLuint;
    FTexture2: GLuint;
    FUniformTransform: GLint;
    FUniformOurTexture1: GLint;
    FUniformOurTexture2: GLint;
  public
    procedure Initialize; override;
    procedure Update(const ADeltaTimeSec, ATotalTimeSec: Double); override;
    procedure Shutdown; override;
    procedure KeyDown(const AKey: Integer; const AShift: TShiftState); override;
  end;

implementation

uses
  System.UITypes,
  Neslib.Stb.Image,
  Neslib.FastMath;

const
  { Each vertex consists of a 3-element position and 2-element texture coordinate. }
  VERTICES: array [0..19] of Single = (
    // Positions       // Texture Coords
     0.5,  0.5, 0.0,   1.0, 1.0,  // Top Right
     0.5, -0.5, 0.0,   1.0, 0.0,  // Bottom Right
    -0.5, -0.5, 0.0,   0.0, 0.0,  // Bottom Left
    -0.5,  0.5, 0.0,   0.0, 1.0); // Top Left

const
  { The indices define 2 triangles forming a rectangle }
  INDICES: array [0..5] of UInt16 = (
    0, 1, 3,
    1, 2, 3);

{ TTransformations }

procedure TTransformations.Initialize;
var
  VertexLayout: TVertexLayout;
  Data: TBytes;
  Image: Pointer;
  Width, Height, Components: Integer;
begin
  { Initialize the asset manager }
  TAssets.Initialize;

  { Build and compile our shader program }
  FShader := TShader.Create('shaders/transform.vs', 'shaders/transform.fs');
  FUniformTransform := FShader.GetUniformLocation('transform');
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
  Image := stbi_load_from_memory(Data, Length(Data), Width, Height, Components, 3);
  Assert(Assigned(Image));
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, Width, Height, 0, GL_RGB, GL_UNSIGNED_BYTE, Image);
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
  Image := stbi_load_from_memory(Data, Length(Data), Width, Height, Components, 3);
  Assert(Assigned(Image));
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, Width, Height, 0, GL_RGB, GL_UNSIGNED_BYTE, Image);
  glGenerateMipmap(GL_TEXTURE_2D);
  stbi_image_free(Image);
  glBindTexture(GL_TEXTURE_2D, 0);
  glErrorCheck;
end;

procedure TTransformations.KeyDown(const AKey: Integer; const AShift: TShiftState);
begin
  { Terminate app when Esc key is pressed }
  if (AKey = vkEscape) then
    Terminate;
end;

procedure TTransformations.Shutdown;
begin
  glDeleteTextures(1, @FTexture1);
  glDeleteTextures(2, @FTexture2);
end;

procedure TTransformations.Update(const ADeltaTimeSec, ATotalTimeSec: Double);
var
  Transform, Rotation: TMatrix4;
begin
  { Define the viewport dimensions }
  glViewport(0, 0, Width, Height);

  { Clear the color buffer }
  glClearColor(0.2, 0.3, 0.3, 1.0);
  glClear(GL_COLOR_BUFFER_BIT);

  FShader.Use;

  { Bind Textures using texture units }
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, FTexture1);
  glUniform1i(FUniformOurTexture1, 0);
  glActiveTexture(GL_TEXTURE1);
  glBindTexture(GL_TEXTURE_2D, FTexture2);
  glUniform1i(FUniformOurTexture2, 1);

  { Create transformations }
  Transform.InitTranslation(0.5, -0.5, 0);
  Rotation.InitRotationZ(ATotalTimeSec * Radians(50));
  Transform := Rotation * Transform;

  { Set transformation }
  glUniformMatrix4fv(FUniformTransform, 1, GL_FALSE, @Transform);

  { Draw the rectangle }
  FVertexArray.Render;
end;

end.
