unit Sample.Common;

{$INCLUDE 'Sample.inc'}

interface

uses
  {$INCLUDE 'OpenGL.inc'}
  Neslib.FastMath,
  Sample.Classes;

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

{ This function loads a texture from file in assets.zip.
  Note: texture loading functions like these are usually managed by a 'Resource
  Manager' that manages all resources (like textures, models, audio).
  For learning purposes we'll just define it as a utility function. }
function LoadTexture(const APath: String; const AAlpha: Boolean = False): GLuint;

implementation

uses
  System.SysUtils,
  Neslib.Stb.Image;

function LoadTexture(const APath: String; const AAlpha: Boolean): GLuint;
var
  Width, Height, Components, Format, Wrap: Integer;
  Image: Pointer;
  Data: TBytes;
  SupportsMipmaps: Boolean;
begin
  { Set options accoridng to AAlpha value }
  if AAlpha then
  begin
    Components := 4;
    Format := GL_RGBA;

    { Use GL_CLAMP_TO_EDGE to prevent semi-transparent borders.
      Due to interpolation it takes value from next repeat }
    Wrap := GL_CLAMP_TO_EDGE;
  end
  else
  begin
    Components := 3;
    Format := GL_RGB;
    Wrap := GL_REPEAT;
  end;

  { Generate OpenGL texture }
  glGenTextures(1, @Result);
  glBindTexture(GL_TEXTURE_2D, Result);

  { Load texture }
  Data := TAssets.Load(APath);
  Assert(Assigned(Data));
  Image := stbi_load_from_memory(Data, Length(Data), Width, Height, Components, Components);
  Assert(Assigned(Image));

  { Set texture data }
  glTexImage2D(GL_TEXTURE_2D, 0, Format, Width, Height, 0, Format, GL_UNSIGNED_BYTE, Image);

  { Generate mipmaps if possible. With OpenGL ES, mipmaps are only supported
    if both dimensions are a power of two. }
  SupportsMipmaps := IsPowerOfTwo(Width) and IsPowerOfTwo(Height);
  if (SupportsMipmaps) then
    glGenerateMipmap(GL_TEXTURE_2D)
  else
    { Only clamp-to-edge is supported for NPOT textures }
    Wrap := GL_CLAMP_TO_EDGE;

  { Set texture parameters }
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, Wrap);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, Wrap);

  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  if (SupportsMipmaps) then
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR)
  else
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

  { Free original image }
  stbi_image_free(Image);

  { Unbind }
  glBindTexture(GL_TEXTURE_2D, 0);
  glErrorCheck;
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

end.
