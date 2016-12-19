unit App;

{$INCLUDE 'Sample.inc'}

interface

uses
  System.Classes,
  {$INCLUDE 'OpenGL.inc'}
  Sample.App;

type
  THelloTriangle = class(TApplication)
  private
    FShaderProgram: GLint;
    FVertexBuffer: GLuint;
    FIndexBuffer: GLuint;
    FAttributePosition: Integer;
  public
    procedure Initialize; override;
    procedure Update(const ADeltaTimeSec, ATotalTimeSec: Double); override;
    procedure Shutdown; override;
    procedure KeyDown(const AKey: Integer; const AShift: TShiftState); override;
  end;

implementation

uses
  System.UITypes,
  System.SysUtils;

const
  { Shaders }
  VERTEX_SHADER_SOURCE =
    'attribute vec3 position;'#10+

    'void main()'#10+
    '{'#10+
    '  gl_Position = vec4(position.x, position.y, position.z, 1.0);'#10+
    '}';

  FRAGMENT_SHADER_SOURCE =
    'void main()'#10+
    '{'#10+
    '  gl_FragColor = vec4(1.0, 0.5, 0.2, 1.0);'#10+
    '}';

const
  { Plane vertices and indices.
    Defines 4 vertices and 2 triangles. }
  VERTICES: array [0..11] of Single = (
     0.5,  0.5, 0.0,  // Top Right
     0.5, -0.5, 0.0,  // Bottom Right
    -0.5, -0.5, 0.0,  // Bottom Left
    -0.5,  0.5, 0.0); // Top Left

  INDICES: array [0..5] of UInt16 = (
    0, 1, 3,  // First Triangle
    1, 2, 3); // Second Triangle

{ THelloTriangle }

procedure THelloTriangle.Initialize;
var
  VertexShader, FragmentShader, Status, LogLength: GLint;
  Source: RawByteString;
  SourcePtr: MarshaledAString;
  Log: TBytes;
begin
  { Build and compile our shader program }

  { Vertex shader }
  VertexShader := glCreateShader(GL_VERTEX_SHADER);
  Source := VERTEX_SHADER_SOURCE;
  SourcePtr := MarshaledAString(Source);
  glShaderSource(VertexShader, 1, @SourcePtr, nil);
  glCompileShader(VertexShader);
  { Check for compile time errors }
  glGetShaderiv(VertexShader, GL_COMPILE_STATUS, @Status);
  if (Status <> GL_TRUE) then
  begin
    glGetShaderiv(VertexShader, GL_INFO_LOG_LENGTH, @LogLength);
    if (LogLength > 0) then
    begin
      SetLength(Log, LogLength);
      glGetShaderInfoLog(VertexShader, LogLength, @LogLength, @Log[0]);
      raise Exception.Create(TEncoding.ANSI.GetString(Log));
    end;
  end;

  { Fragment shader }
  FragmentShader := glCreateShader(GL_FRAGMENT_SHADER);
  Source := FRAGMENT_SHADER_SOURCE;
  SourcePtr := MarshaledAString(Source);
  glShaderSource(FragmentShader, 1, @SourcePtr, nil);
  glCompileShader(FragmentShader);
  { Check for compile time errors }
  glGetShaderiv(FragmentShader, GL_COMPILE_STATUS, @Status);
  if (Status <> GL_TRUE) then
  begin
    glGetShaderiv(FragmentShader, GL_INFO_LOG_LENGTH, @LogLength);
    if (LogLength > 0) then
    begin
      SetLength(Log, LogLength);
      glGetShaderInfoLog(FragmentShader, LogLength, @LogLength, @Log[0]);
      raise Exception.Create(TEncoding.ANSI.GetString(Log));
    end;
  end;

  { Link shaders }
  FShaderProgram := glCreateProgram;
  glAttachShader(FShaderProgram, VertexShader);
  glAttachShader(FShaderProgram, FragmentShader);
  glLinkProgram(FShaderProgram);
  { Check for linking errors }
  glGetProgramiv(FShaderProgram, GL_LINK_STATUS, @Status);
  if (Status <> GL_TRUE) then
  begin
    glGetProgramiv(FShaderProgram, GL_INFO_LOG_LENGTH, @LogLength);
    if (LogLength > 0) then
    begin
      SetLength(Log, LogLength);
      glGetProgramInfoLog(FShaderProgram, LogLength, @LogLength, @Log[0]);
      raise Exception.Create(TEncoding.ANSI.GetString(Log));
    end;
  end;

  { Get attribute locations }
  FAttributePosition := glGetAttribLocation(FShaderProgram, 'position');
  Assert(FAttributePosition >= 0);

  { Don't need shaders anymore }
  glDeleteShader(VertexShader);
  glDeleteShader(FragmentShader);

  { Set up vertex data (and buffer(s)) }
  glGenBuffers(1, @FVertexBuffer);
  glGenBuffers(1, @FIndexBuffer);

  glBindBuffer(GL_ARRAY_BUFFER, FVertexBuffer);
  glBufferData(GL_ARRAY_BUFFER, SizeOf(VERTICES), @VERTICES, GL_STATIC_DRAW);
  glBindBuffer(GL_ARRAY_BUFFER, 0);

  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, FIndexBuffer);
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, SizeOf(INDICES), @INDICES, GL_STATIC_DRAW);
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);

  { Build the "Release | Wireframe" configuration to render wireframe polygons. }
  {$IF Defined(WIREFRAME) and not Defined(MOBILE)}
  glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
  {$ENDIF}
end;

procedure THelloTriangle.KeyDown(const AKey: Integer; const AShift: TShiftState);
begin
  { Terminate app when Esc key is pressed }
  if (AKey = vkEscape) then
    Terminate;
end;

procedure THelloTriangle.Shutdown;
begin
  { Properly de-allocate all resources once they've outlived their purpose }
  glDeleteBuffers(1, @FIndexBuffer);
  glDeleteBuffers(1, @FVertexBuffer);
  glDeleteProgram(FShaderProgram);
end;

procedure THelloTriangle.Update(const ADeltaTimeSec, ATotalTimeSec: Double);
begin
  { Define the viewport dimensions }
  glViewport(0, 0, Width, Height);

  { Clear the color buffer }
  glClearColor(0.2, 0.3, 0.3, 1.0);
  glClear(GL_COLOR_BUFFER_BIT);

  { Render the two triangles (that form a rectangle) }
  glBindBuffer(GL_ARRAY_BUFFER, FVertexBuffer);
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, FIndexBuffer);

  { Configure the "position" attribute }
  glVertexAttribPointer(FAttributePosition, 3, GL_FLOAT, GL_FALSE,
    3 * SizeOf(Single), Pointer(0));
  glEnableVertexAttribArray(FAttributePosition);

  glUseProgram(FShaderProgram);
  glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_SHORT, nil);

  { Restore state }
  glDisableVertexAttribArray(FAttributePosition);
  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
end;

end.
