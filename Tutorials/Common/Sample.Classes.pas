unit Sample.Classes;

{$INCLUDE 'Sample.inc'}

interface

uses
  {$INCLUDE 'OpenGL.inc'}
  System.Classes,
  System.Types,
  System.UITypes,
  System.SysUtils,
  System.Zip,
  Neslib.FastMath;

type
  { Static class for managing assets.

    For easy deployment, all assets are stored in a single ZIP file called
    assets.zip. This ZIP file is linked into the executable as a resource named
    ASSETS.

    For maximum portability, all file names and folder names in the ZIP file
    should be in lower case.

    To add the assets.zip file to your project in Delphi, go to "Project |
    Resources and Images..." and add the assets.zip file and set the "Resource
    identifier" to ASSETS. }
  TAssets = class // static
  {$REGION 'Internal Declarations'}
  private class var
    FStream: TResourceStream;
    FZipFile: TZipFile;
  public
    class constructor Create;
    class destructor Destroy;
  {$ENDREGION 'Internal Declarations'}
  public
    { Initializes the asset manager.
      Must be called before calling any other methods. }
    class procedure Initialize; static;

    { Loads a file into a byte array.

      Parameters:
        APath: the path to the file in assets.zip. If the path contains
          directories, forward slashes ('/') should be used.

      Returns:
        A byte array containing the file data. }
    class function Load(const APath: String): TBytes; static;

    { Loads a file into a RawByteString.

      Parameters:
        APath: the path to the file in assets.zip. If the path contains
          directories, forward slashes ('/') should be used.

      Returns:
        A RawByteString containing the file data. }
    class function LoadRawByteString(const APath: String): RawByteString; static;
  end;

type
  { Encapsulates an OpenGL shader program consisting of a vertex shader and
    fragment shader. Implemented in the TShader class. }
  IShader = interface
  ['{6389D101-5FD2-4AEA-817A-A4AF21C7189D}']
    {$REGION 'Internal Declarations'}
    function _GetHandle: GLuint;
    {$ENDREGION 'Internal Declarations'}

    { Uses (activates) the shader for rendering }
    procedure Use;

    { Retrieves the location of a "uniform" (global variable) in the shader.

      Parameters:
        AName: the name of the uniform to retrieve

      Returns:
        The location of the uniform.

      Raises an exception if the AName is not found in the shader. }
    function GetUniformLocation(const AName: RawByteString): Integer;

    { Low level OpenGL handle of the shader. }
    property Handle: GLuint read _GetHandle;
  end;

type
  { Implements IShader }
  TShader = class(TInterfacedObject, IShader)
  {$REGION 'Internal Declarations'}
  private
    FProgram: GLuint;
  private
    class function CreateShader(const AShaderPath: String;
      const AShaderType: GLenum): GLuint; static;
  protected
    { IShader }
    function _GetHandle: GLuint;
    procedure Use;
    function GetUniformLocation(const AName: RawByteString): Integer;
  {$ENDREGION 'Internal Declarations'}
  public
    { Creates a shader.

      Parameters:
        AVertexShaderPath: path into the assets.zip file containing the vertex
          shader (eg. 'shaders/MyShader.vs').
        AFragmentShaderPath: path into the assets.zip file containing the
          fragment shader (eg. 'shaders/MyShader.fs'). }
    constructor Create(const AVertexShaderPath, AFragmentShaderPath: String);
    destructor Destroy; override;
  end;

type
  { Represents the layout of a single vertex in an IVertexArray.
    You define a vertex layout like this:

    <source>
    var
      Layout: TVertexLayout;
    begin
      Layout.Start(MyShader)
        .Add('position', 3)
        .Add('texcoord', 2);
    end;
    </source>
     }
  PVertexLayout = ^TVertexLayout;
  TVertexLayout = packed record
  {$REGION 'Internal Declarations'}
  private const
    MAX_ATTRIBUTES = 8;
  private type
    TAttribute = packed record
      Location: Byte;
      Size: Byte;
      Normalized: Byte;
      Offset: Byte;
    end;
  private
    FProgram: GLuint;
    FAttributes: array [0..MAX_ATTRIBUTES - 1] of TAttribute;
    FStride: Byte;
    FAttributeCount: Int8;
  {$ENDREGION 'Internal Declarations'}
  public
    { Starts the definition of the vertex layout. You need to call this method
      before calling Add.

      Parameters:
        AShader: the shader that uses this vertex layout. Cannot be nil.

      Returns:
        This instance, for use in a fluent API. }
    function Start(const AShader: IShader): PVertexLayout;

    { Adds a vertex attribute to the layout.

      Parameters:
        AName: the name of the attribute as it appears in the shader.
        ACount: number of floating-point values for the attribute. For example,
          a 3D position contains 3 values and a 2D texture coordinate contains
          2 values.
        ANormalized: (optional) if set to True, values will be normalized from a
          0-255 range to 0.0 - 0.1 in the shader. Defaults to False.

      Returns:
        This instance, for use in a fluent API. }
    function Add(const AName: RawByteString; const ACount: Integer;
      const ANormalized: Boolean = False): PVertexLayout;
  end;

type
  { Encapsulates an OpenGL Vertex Array Object (VAO) on systems that support it.
    A VAO manages the state of a Vertex Buffer Object (VBO) and Index (or
    Element) Buffer Object (EBO).

    On systems that don't support VAO's, this type manages the VBO and EBO
    manually.

    Implemented in the TVertexArray class }
  IVertexArray = interface
  ['{F0A79A83-B01B-4EFE-863F-BD56D02A8AB0}']
    { Renders the vertex array.

      If you want to render the same VAO (mesh) multiple times for the same
      frame, then it is more efficient to call this method (multiple times)
      inside a BeginRender/EndRender block.

      If you render this VAO only once (per frame), then you don't need to call
      BeginRender and EndRender }
    procedure Render;

    { Begins rendering with this VAO.

      Call this method if you want to render this VAO (mesh) multiple times
      for the same frame to increase performance. Call this method before your
      first call to Render.

      If you render this VAO only once (per frame), then you don't need to call
      BeginRender. }
    procedure BeginRender;

    { Ends rendering with this VAO. You @bold(must) call this method if you
      called BeginRender. Call it after your last call to Render. }
    procedure EndRender;
  end;

type
  { Implements IVertexArray }
  TVertexArray = class(TInterfacedObject, IVertexArray)
  {$REGION 'Internal Declarations'}
  private class var
    FSupportsVAO: Boolean;
    FInitialized: Boolean;
    glGenVertexArrays: procedure(n: GLsizei; arrays: PGLuint); {$IFDEF MSWINDOWS}stdcall{$ELSE}cdecl{$ENDIF};
    glBindVertexArray: procedure(array_: GLuint); {$IFDEF MSWINDOWS}stdcall{$ELSE}cdecl{$ENDIF};
    glDeleteVertexArrays: procedure(n: GLsizei; {$IFDEF MSWINDOWS}const{$ENDIF} arrays: PGLuint); {$IFDEF MSWINDOWS}stdcall{$ELSE}cdecl{$ENDIF};
    {$IFDEF ANDROID}
    FLibHandle: THandle;
    {$ENDIF}
  private
    FVertexBuffer: GLuint;
    FIndexBuffer: GLuint;
    FVertexArray: GLuint;
    FAttributes: TArray<TVertexLayout.TAttribute>;
    FStride: Integer;
    FIndexCount: Integer;
    FRenderStarted: Boolean;
  private
    class procedure Initialize; static;
  private
    constructor Create(const ALayout: TVertexLayout;
      const AVertices; const ASizeOfVertices: Integer;
      const AIndices; const AIndexCount: Integer); overload;
  protected
    { IVertexArray }
    procedure Render;
    procedure BeginRender;
    procedure EndRender;
  public
    class constructor Create;
    class destructor Destroy;
  {$ENDREGION 'Internal Declarations'}
  public
    { Creates a vertex array.

      Parameters:
        ALayout: the layout of the vertices in the array.
        AVertices: data containing the vertices in the given layout.
        ASizeOfVertices: size of the AVertices vertex data.
        AIndices: array of indices to the vertices defining the triangles.
          Must contain a multiple of 3 elements. }
    constructor Create(const ALayout: TVertexLayout;
      const AVertices; const ASizeOfVertices: Integer;
      const AIndices: TArray<UInt16>); overload;
    constructor Create(const ALayout: TVertexLayout;
      const AVertices; const ASizeOfVertices: Integer;
      const AIndices: array of UInt16); overload;
    destructor Destroy; override;
  end;

type
  { Represents a camera in 3D space.
    Implemented in the TCamera class. }
  ICamera = interface
  ['{8155AE07-6148-4E4D-8674-3C1B2A5082E4}']
    {$REGION 'Internal Declarations'}
    function _GetPosition: TVector3;
    procedure _SetPosition(const AValue: TVector3);
    function _GetFront: TVector3;
    procedure _SetFront(const AValue: TVector3);
    function _GetUp: TVector3;
    procedure _SetUp(const AValue: TVector3);
    function _GetRight: TVector3;
    procedure _SetRight(const AValue: TVector3);
    function _GetWorldUp: TVector3;
    procedure _SetWorldUp(const AValue: TVector3);
    function _GetYaw: Single;
    procedure _SetYaw(const AValue: Single);
    function _GetPitch: Single;
    procedure _SetPitch(const AValue: Single);
    function _GetMovementSpeed: Single;
    procedure _SetMovementSpeed(const AValue: Single);
    function _GetSensitivity: Single;
    procedure _SetSensitivity(const AValue: Single);
    function _GetZoom: Single;
    procedure _SetZoom(const AValue: Single);
    {$ENDREGION 'Internal Declarations'}

    { Returns the view matrix calculated using Euler Angles and the LookAt
      matrix }
    function GetViewMatrix: TMatrix4;

    { Call this when the view (screen) has resized.

      Parameters:
        AWidth: new width of the view
        AHeight: new height of the view }
    procedure ViewResized(const AWidth, AHeight: Integer);

    { Handles camera-related key down events.

      Parameters:
        AKey: virtual key code (one of the vk* constants in the System.UITypes
          unit)

      Processes WASD and cursor keys to move the camera (Walk Around). }
    procedure ProcessKeyDown(const AKey: Integer);

    { Handles camera-related key up events.

      Parameters:
        AKey: virtual key code (one of the vk* constants in the System.UITypes
          unit)

      Processes WASD and cursor keys to move the camera (Walk Around). }
    procedure ProcessKeyUp(const AKey: Integer);

    { Handles camera-related mouse/finger down events.

      Parameters:
        AX: X-position
        AY: Y-position

      Handles mouse movement to orient the camera (Look Around).
      When the mouse/finger is held down near an edge of the screen, it is used
      to simulate a WASD key event. }
    procedure ProcessMouseDown(const AX, AY: Single);

    { Handles camera-related mouse/finger movement events.

      Parameters:
        AX: X-position
        AY: Y-position

      Handles mouse movement to orient the camera (Look Around).
      When the mouse/finger is held down near an edge of the screen, it is used
      to simulate a WASD key event. }
    procedure ProcessMouseMove(const AX, AY: Single);

    { Handles camera-related mouse/finger up events.

      Handles mouse movement to orient the camera (Look Around).
      When the mouse/finger is held down near an edge of the screen, it is used
      to simulate a WASD key event. }
    procedure ProcessMouseUp;

    { Handles camera-related mouse wheel events.

      Parameters:
        AWheelDelta: number of notches the mouse wheel moved.

      Handles zooming the camera in and out (changing the Field of View) }
    procedure ProcessMouseWheel(const AWheelDelta: Integer);

    { Processes any input that happened since the last frame.

      Parameters:
        ADeltaTimeSec: time since the last frame in seconds. }
    procedure HandleInput(const ADeltaTimeSec: Single);

    { Position of the camera in the world.
      Defaults to the world origin (0, 0, 0). }
    property Position: TVector3 read _GetPosition write _SetPosition;

    { Camera vector pointing forward.
      Default to negative Z identity (0, 0, -1) }
    property Front: TVector3 read _GetFront write _SetFront;

    { Camera vector pointing up. }
    property Up: TVector3 read _GetUp write _SetUp;

    { Camera vector pointing right. }
    property Right: TVector3 read _GetRight write _SetRight;

    { World up direction.
      Defaults to Y identity (0, 1, 0) }
    property WorldUp: TVector3 read _GetWorldUp write _SetWorldUp;

    { Yaw angle in degrees.
      Defaults to -90 }
    property Yaw: Single read _GetYaw write _SetYaw;

    { Pitch angle in degrees.
      Defaults to 0 }
    property Pitch: Single read _GetPitch write _SetPitch;

    { Movement speed in units per second.
      Defaults to 3. }
    property MovementSpeed: Single read _GetMovementSpeed write _SetMovementSpeed;

    { Movement sensitivity.
      Defaults to 0.25 }
    property Sensitivity: Single read _GetSensitivity write _SetSensitivity;

    { Zoom angle in degrees (aka Field of View).
      Defaults to 45 }
    property Zoom: Single read _GetZoom write _SetZoom;
  end;

type
  { Implements TCamera }
  TCamera = class(TInterfacedObject, ICamera)
  public const
    DEFAULT_YAW         = -90;
    DEFAULT_PITCH       = 0;
    DEFAULT_SPEED       = 3;
    DEFAULT_SENSITIVITY = 0.25;
    DEFAULT_ZOOM        = 45;
  {$REGION 'Internal Declarations'}
  private
    FPosition: TVector3;
    FFront: TVector3;
    FUp: TVector3;
    FRight: TVector3;
    FWorldUp: TVector3;
    FYaw: Single;
    FPitch: Single;
    FMovementSpeed: Single;
    FSensitivity: Single;
    FZoom: Single;
  private
    { Input }
    FLastX: Single;
    FLastY: Single;
    FScreenEdge: TRectF;
    FLookAround: Boolean;
    FKeyW: Boolean;
    FKeyA: Boolean;
    FKeyS: Boolean;
    FKeyD: Boolean;
  protected
    function _GetPosition: TVector3;
    procedure _SetPosition(const AValue: TVector3);
    function _GetFront: TVector3;
    procedure _SetFront(const AValue: TVector3);
    function _GetUp: TVector3;
    procedure _SetUp(const AValue: TVector3);
    function _GetRight: TVector3;
    procedure _SetRight(const AValue: TVector3);
    function _GetWorldUp: TVector3;
    procedure _SetWorldUp(const AValue: TVector3);
    function _GetYaw: Single;
    procedure _SetYaw(const AValue: Single);
    function _GetPitch: Single;
    procedure _SetPitch(const AValue: Single);
    function _GetMovementSpeed: Single;
    procedure _SetMovementSpeed(const AValue: Single);
    function _GetSensitivity: Single;
    procedure _SetSensitivity(const AValue: Single);
    function _GetZoom: Single;
    procedure _SetZoom(const AValue: Single);

    function GetViewMatrix: TMatrix4;
    procedure ViewResized(const AWidth, AHeight: Integer);
    procedure ProcessKeyDown(const AKey: Integer);
    procedure ProcessKeyUp(const AKey: Integer);
    procedure ProcessMouseDown(const AX, AY: Single);
    procedure ProcessMouseMove(const AX, AY: Single);
    procedure ProcessMouseUp;
    procedure ProcessMouseWheel(const AWheelDelta: Integer);
    procedure HandleInput(const ADeltaTimeSec: Single);
  private
    procedure ProcessMouseMovement(const AXOffset, AYOffset: Single;
      const AConstrainPitch: Boolean = True);
    procedure UpdateScreenEdge(const AViewWidth, AViewHeight: Single);
    procedure UpdateCameraVectors;
  {$ENDREGION 'Internal Declarations'}
  public
    { Creates a camera.

      Parameters:
        AViewWidth: width of the view (screen)
        AViewHeight: width of the view (screen)
        APosition: (optional) position of the camera in 3D space.
          Defaults to world origin (0, 0, 0).
        AUp: (optional) world up vector. Defaults to (0, 1, 0).
        AYaw: (optional) yaw angle in degrees. Defaults to -90.
        APitch: (optional) pitch angle in degrees. Defaults to 0. }
    constructor Create(const AViewWidth, AViewHeight: Integer;
      const AYaw: Single = DEFAULT_YAW;
      const APitch: Single = DEFAULT_PITCH); overload;
    constructor Create(const AViewWidth, AViewHeight: Integer;
      const APosition: TVector3; const AYaw: Single = DEFAULT_YAW;
      const APitch: Single = DEFAULT_PITCH); overload;
    constructor Create(const AViewWidth, AViewHeight: Integer;const APosition,
      AUp: TVector3; const AYaw: Single = DEFAULT_YAW;
      const APitch: Single = DEFAULT_PITCH); overload;
  end;

{ In DEBUG mode, checks for any OpenGL error since the last OpenGL call and
  raises an exception of the last OpenGL call failed. Does nothing in RELEASE
  (or non-DEBUG) mode. }
procedure glErrorCheck; {$IFNDEF DEBUG}inline;{$ENDIF}

{ Checks whether an OpenGL extension is supported.

  Parameters:
    AName: name of the extension.

  Returns:
    True if extension is supported. False otherwise. }
function glIsExtensionSupported(const AName: RawByteString): Boolean;

{$IF Defined(MACOS) and not Defined(IOS)}
var
  { Not defined in Macapi.OpenGL.
    Is set in Sample.Platform.Mac. }
  glGenerateMipmap: procedure(target: GLenum); cdecl = nil;
{$ENDIF}

implementation

uses
  {$IFDEF ANDROID}
  Posix.Dlfcn,
  {$ENDIF}
  Sample.Platform;

{$IFDEF DEBUG}
procedure glErrorCheck;
var
  Error: GLenum;
begin
  Error := glGetError;
  if (Error <> GL_NO_ERROR) then
    raise Exception.CreateFmt('OpenGL Error: $%.4x', [Error]);
end;
{$ELSE}
procedure glErrorCheck; inline;
begin
  { Nothing }
end;
{$ENDIF}

var
  GExtensions: RawByteString = '';

function glIsExtensionSupported(const AName: RawByteString): Boolean;
begin
  if (GExtensions = '') then
    GExtensions := RawByteString(MarshaledAString(glGetString(GL_EXTENSIONS)));

  Result := (Pos(AName, GExtensions) >= Low(RawByteString));
end;

{ TAssets }

class constructor TAssets.Create;
begin
  FStream := nil;
  FZipFile := nil;
end;

class destructor TAssets.Destroy;
begin
  FZipFile.DisposeOf;
  FZipFile := nil;

  FStream.DisposeOf;
  FStream := nil;
end;

class procedure TAssets.Initialize;
begin
  if (FStream = nil) then
    FStream := TResourceStream.Create(HInstance, 'ASSETS', RT_RCDATA);

  if (FZipFile = nil) then
  begin
    FZipFile := TZipFile.Create;
    FZipFile.Open(FStream, TZipMode.zmRead);
  end;
end;

class function TAssets.Load(const APath: String): TBytes;
begin
  Assert(Assigned(FZipFile));
  FZipFile.Read(APath, Result);
end;

class function TAssets.LoadRawByteString(const APath: String): RawByteString;
var
  Data: TBytes;
begin
  Assert(Assigned(FZipFile));
  FZipFile.Read(APath, Data);
  if (Data = nil) then
    Result := ''
  else
  begin
    SetLength(Result, Length(Data));
    Move(Data[0], Result[Low(RawByteString)], Length(Data));
  end;
end;

{ TShader }

constructor TShader.Create(const AVertexShaderPath,
  AFragmentShaderPath: String);
var
  Status, LogLength: GLint;
  VertexShader, FragmentShader: GLuint;
  Log: TBytes;
  Msg: String;
begin
  inherited Create;
  FragmentShader := 0;
  VertexShader := CreateShader(AVertexShaderPath, GL_VERTEX_SHADER);
  try
    FragmentShader := CreateShader(AFragmentShaderPath, GL_FRAGMENT_SHADER);
    FProgram := glCreateProgram;

    glAttachShader(FProgram, VertexShader);
    glErrorCheck;

    glAttachShader(FProgram, FragmentShader);
    glErrorCheck;

    glLinkProgram(FProgram);
    glGetProgramiv(FProgram, GL_LINK_STATUS, @Status);

    if (Status <> GL_TRUE) then
    begin
      glGetProgramiv(FProgram, GL_INFO_LOG_LENGTH, @LogLength);
      if (LogLength > 0) then
      begin
        SetLength(Log, LogLength);
        glGetProgramInfoLog(FProgram, LogLength, @LogLength, @Log[0]);
        Msg := TEncoding.ANSI.GetString(Log);
        raise Exception.Create(Msg);
      end;
    end;
    glErrorCheck;
  finally
    if (FragmentShader <> 0) then
      glDeleteShader(FragmentShader);

    if (VertexShader <> 0) then
      glDeleteShader(VertexShader);
  end;
end;

class function TShader.CreateShader(const AShaderPath: String;
  const AShaderType: GLenum): GLuint;
var
  Source: RawByteString;
  SourcePtr: MarshaledAString;
  Status, LogLength: GLint;
  Log: TBytes;
  Msg: String;
begin
  Result := glCreateShader(AShaderType);
  Assert(Result <> 0);
  glErrorCheck;

  Source := TAssets.LoadRawByteString(AShaderPath);
  {$IFNDEF MOBILE}
  { Desktop OpenGL doesn't recognize precision specifiers }
  if (AShaderType = GL_FRAGMENT_SHADER) then
    Source :=
      '#define lowp'#10+
      '#define mediump'#10+
      '#define highp'#10+
      Source;
  {$ENDIF}

  SourcePtr := MarshaledAString(Source);
  glShaderSource(Result, 1, @SourcePtr, nil);
  glErrorCheck;

  glCompileShader(Result);
  glErrorCheck;

  Status := GL_FALSE;
  glGetShaderiv(Result, GL_COMPILE_STATUS, @Status);
  if (Status <> GL_TRUE) then
  begin
    glGetShaderiv(Result, GL_INFO_LOG_LENGTH, @LogLength);
    if (LogLength > 0) then
    begin
      SetLength(Log, LogLength);
      glGetShaderInfoLog(Result, LogLength, @LogLength, @Log[0]);
      Msg := TEncoding.ANSI.GetString(Log);
      raise Exception.Create(Msg);
    end;
  end;
end;

destructor TShader.Destroy;
begin
  glUseProgram(0);
  if (FProgram <> 0) then
    glDeleteProgram(FProgram);
  inherited;
end;

function TShader.GetUniformLocation(const AName: RawByteString): Integer;
begin
  Result := glGetUniformLocation(FProgram, MarshaledAString(AName));
  if (Result < 0) then
    raise Exception.CreateFmt('Uniform "%s" not found in shader', [AName]);
end;

procedure TShader.Use;
begin
  glUseProgram(FProgram);
end;

function TShader._GetHandle: GLuint;
begin
  Result := FProgram;
end;

{ TVertexLayout }

function TVertexLayout.Add(const AName: RawByteString; const ACount: Integer;
  const ANormalized: Boolean): PVertexLayout;
var
  Location, Stride: Integer;
begin
  if (FAttributeCount = MAX_ATTRIBUTES) then
    raise Exception.Create('Too many attributes in vertex layout');

  Stride := FStride + (ACount * SizeOf(Single));
  if (Stride >= 256) then
    raise Exception.Create('Vertex layout too big');

  Location := glGetAttribLocation(FProgram, MarshaledAString(AName));
  if (Location < 0) then
    raise Exception.CreateFmt('Attribute "%s" not found in shader', [AName]);

  Assert(Location <= 255);
  FAttributes[FAttributeCount].Location := Location;
  FAttributes[FAttributeCount].Size := ACount;
  FAttributes[FAttributeCount].Normalized := Ord(ANormalized);
  FAttributes[FAttributeCount].Offset := FStride;

  FStride := Stride;
  Inc(FAttributeCount);

  Result := @Self;
end;

function TVertexLayout.Start(const AShader: IShader): PVertexLayout;
begin
  Assert(Assigned(AShader));
  FillChar(Self, SizeOf(Self), 0);
  FProgram := AShader.Handle;
  Result := @Self;
end;

{ TVertexArray }

constructor TVertexArray.Create(const ALayout: TVertexLayout;
  const AVertices; const ASizeOfVertices: Integer;
  const AIndices: TArray<UInt16>);
begin
  Create(ALayout, AVertices, ASizeOfVertices, AIndices[0], Length(AIndices));
end;

procedure TVertexArray.BeginRender;
var
  I: Integer;
begin
  if (FRenderStarted) then
    Exit;

  if (FSupportsVAO) then
    { When VAO's are supported, we simple need to bind it... }
    glBindVertexArray(FVertexArray)
  else
  begin
    { Otherwise, we need to manually bind the VBO and EBO and configure and
      enable the attributes. }
    glBindBuffer(GL_ARRAY_BUFFER, FVertexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, FIndexBuffer);

    for I := 0 to Length(FAttributes) - 1 do
    begin
      glVertexAttribPointer(
        FAttributes[I].Location,
        FAttributes[I].Size,
        GL_FLOAT,
        FAttributes[I].Normalized,
        FStride,
        Pointer(FAttributes[I].Offset));
      glEnableVertexAttribArray(FAttributes[I].Location);
    end;
  end;

  FRenderStarted := True;
end;

constructor TVertexArray.Create(const ALayout: TVertexLayout; const AVertices;
  const ASizeOfVertices: Integer; const AIndices: array of UInt16);
begin
  Create(ALayout, AVertices, ASizeOfVertices, AIndices[0], Length(AIndices));
end;

class destructor TVertexArray.Destroy;
begin
  {$IFDEF ANDROID}
  if (FLibHandle <> 0) then
    dlClose(FLibHandle);
  {$ENDIF}
end;

constructor TVertexArray.Create(const ALayout: TVertexLayout; const AVertices;
  const ASizeOfVertices: Integer; const AIndices;
  const AIndexCount: Integer);
var
  I: Integer;
begin
  inherited Create;
  if (not FInitialized) then
    Initialize;

  FIndexCount := AIndexCount;

  { Create vertex buffer and index buffer. }
  glGenBuffers(1, @FVertexBuffer);
  glGenBuffers(1, @FIndexBuffer);

  if (FSupportsVAO) then
  begin
    glGenVertexArrays(1, @FVertexArray);
    glBindVertexArray(FVertexArray);
  end;

  glBindBuffer(GL_ARRAY_BUFFER, FVertexBuffer);
  glBufferData(GL_ARRAY_BUFFER, ASizeOfVertices, @AVertices, GL_STATIC_DRAW);

  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, FIndexBuffer);
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, AIndexCount * SizeOf(UInt16), @AIndices, GL_STATIC_DRAW);

  if (FSupportsVAO) then
  begin
    { We can configure the attributes as part of the VAO }
    for I := 0 to ALayout.FAttributeCount - 1 do
    begin
      glVertexAttribPointer(
        ALayout.FAttributes[I].Location,
        ALayout.FAttributes[I].Size,
        GL_FLOAT,
        ALayout.FAttributes[I].Normalized,
        ALayout.FStride,
        Pointer(ALayout.FAttributes[I].Offset));
      glEnableVertexAttribArray(ALayout.FAttributes[I].Location);
    end;

    { We can unbind the vertex buffer now since it is registered with the VAO.
      We cannot unbind the index buffer though. }
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
  end
  else
  begin
    { VAO's are not supported. We need to keep track of the attributes
      manually }
    SetLength(FAttributes, ALayout.FAttributeCount);
    Move(ALayout.FAttributes[0], FAttributes[0],
      ALayout.FAttributeCount * SizeOf(TVertexLayout.TAttribute));
    FStride := ALayout.FStride;
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
  end;
  glErrorCheck;
end;

class constructor TVertexArray.Create;
begin
  FInitialized := False;
end;

destructor TVertexArray.Destroy;
begin
  if (FSupportsVAO) then
    glDeleteVertexArrays(1, @FVertexArray);

  glDeleteBuffers(1, @FIndexBuffer);
  glDeleteBuffers(1, @FVertexBuffer);
  inherited;
end;

procedure TVertexArray.EndRender;
var
  I: Integer;
begin
  if (not FRenderStarted) then
    Exit;

  FRenderStarted := False;

  if (FSupportsVAO) then
    { When VAO's are supported, we simple unbind it... }
    glBindVertexArray(0)
  else
  begin
    { Otherwise, we need to manually unbind the VBO and EBO and disable the
      attributes. }
    for I := 0 to Length(FAttributes) - 1 do
      glDisableVertexAttribArray(FAttributes[I].Location);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
  end;
  glErrorCheck;
end;

class procedure TVertexArray.Initialize;
begin
  {$IF Defined(MSWINDOWS)}
  FSupportsVAO := Assigned(Winapi.OpenGLExt.glGenVertexArrays);
  glGenVertexArrays := Winapi.OpenGLExt.glGenVertexArrays;
  glBindVertexArray := Winapi.OpenGLExt.glBindVertexArray;
  glDeleteVertexArrays := Winapi.OpenGLExt.glDeleteVertexArrays;
  {$ELSEIF Defined(IOS)}
  FSupportsVAO := glIsExtensionSupported('GL_OES_vertex_array_object');
  glGenVertexArrays := glGenVertexArraysOES;
  glBindVertexArray := glBindVertexArrayOES;
  glDeleteVertexArrays := glDeleteVertexArraysOES;
  {$ELSEIF Defined(MACOS)}
  FSupportsVAO := Assigned(glGenVertexArraysAPPLE);
  glGenVertexArrays := glGenVertexArraysAPPLE;
  glBindVertexArray := glBindVertexArrayAPPLE;
  glDeleteVertexArrays := glDeleteVertexArraysAPPLE;
  {$ELSEIF Defined(ANDROID)}
  FSupportsVAO := glIsExtensionSupported('GL_OES_vertex_array_object');
  if (FSupportsVAO) then
  begin
    FLibHandle := dlopen(AndroidGles2Lib, RTLD_LAZY);
    FSupportsVAO := (FLibHandle <> 0);
    if (FSupportsVAO) then
    begin
      glGenVertexArrays := dlsym(FLibHandle, 'glGenVertexArraysOES');
      glBindVertexArray := dlsym(FLibHandle, 'glBindVertexArrayOES');
      glDeleteVertexArrays := dlsym(FLibHandle, 'glDeleteVertexArraysOES');
    end;
  end;
  {$ENDIF}

  FSupportsVAO := FSupportsVAO and Assigned(glGenVertexArrays)
    and Assigned(glBindVertexArray) and Assigned(glDeleteVertexArrays);

  FInitialized := True;
end;

procedure TVertexArray.Render;
begin
  if (not FRenderStarted) then
  begin
    BeginRender;
    glDrawElements(GL_TRIANGLES, FIndexCount, GL_UNSIGNED_SHORT, nil);
    EndRender;
  end
  else
    glDrawElements(GL_TRIANGLES, FIndexCount, GL_UNSIGNED_SHORT, nil);
end;

{ TCamera }

constructor TCamera.Create(const AViewWidth, AViewHeight: Integer; const AYaw,
  APitch: Single);
begin
  Create(AViewWidth, AViewHeight, Vector3(0, 0, 0), Vector3(0, 1, 0), AYaw, APitch);
end;

constructor TCamera.Create(const AViewWidth, AViewHeight: Integer;
  const APosition, AUp: TVector3; const AYaw, APitch: Single);
begin
  inherited Create;
  FFront := Vector3(0, 0, -1);
  FMovementSpeed := DEFAULT_SPEED;
  FSensitivity := DEFAULT_SENSITIVITY;
  FZoom := DEFAULT_ZOOM;
  FPosition := APosition;
  FWorldUp := AUp;
  FYaw := AYaw;
  FPitch := APitch;
  UpdateScreenEdge(AViewWidth, AViewHeight);
  UpdateCameraVectors;
end;

function TCamera.GetViewMatrix: TMatrix4;
begin
  Result.InitLookAtRH(FPosition, FPosition + FFront, FUp);
end;

procedure TCamera.HandleInput(const ADeltaTimeSec: Single);
var
  Velocity: Single;
begin
  Velocity := FMovementSpeed * ADeltaTimeSec;
  if (FKeyW) then
    FPosition := FPosition + (FFront * Velocity);

  if (FKeyS) then
    FPosition := FPosition - (FFront * Velocity);

  if (FKeyA) then
    FPosition := FPosition - (FRight * Velocity);

  if (FKeyD) then
    FPosition := FPosition + (FRight * Velocity);
end;

procedure TCamera.ProcessKeyDown(const AKey: Integer);
begin
  if (AKey = vkW) or (AKey = vkUp) then
    FKeyW := True;

  if (AKey = vkA) or (AKey = vkLeft) then
    FKeyA := True;

  if (AKey = vkS) or (AKey = vkDown) then
    FKeyS := True;

  if (AKey = vkD) or (AKey = vkRight) then
    FKeyD := True;
end;

procedure TCamera.ProcessKeyUp(const AKey: Integer);
begin
  if (AKey = vkW) or (AKey = vkUp) then
    FKeyW := False;

  if (AKey = vkA) or (AKey = vkLeft) then
    FKeyA := False;

  if (AKey = vkS) or (AKey = vkDown) then
    FKeyS := False;

  if (AKey = vkD) or (AKey = vkRight) then
    FKeyD := False;
end;

procedure TCamera.ProcessMouseDown(const AX, AY: Single);
begin
  { Check if mouse/finger is pressed near the edge of the screen.
    If so, simulate a WASD key event. This way, we can move the camera around
    on mobile devices that don't have a keyboard. }
  FLookAround := True;

  if (AX < FScreenEdge.Left) then
  begin
    FKeyA := True;
    FLookAround := False;
  end
  else
  if (AX > FScreenEdge.Right) then
  begin
    FKeyD := True;
    FLookAround := False;
  end;

  if (AY < FScreenEdge.Top) then
  begin
    FKeyW := True;
    FLookAround := False;
  end
  else
  if (AY > FScreenEdge.Bottom) then
  begin
    FKeyS := True;
    FLookAround := False;
  end;

  if (FLookAround) then
  begin
    { Mouse/finger was pressed in center area of screen.
      This is used for Look Around mode. }
    FLastX := AX;
    FLastY := AY;
  end;
end;

procedure TCamera.ProcessMouseMove(const AX, AY: Single);
var
  XOffset, YOffset: Single;
begin
  if (FLookAround) then
  begin
    XOffset := AX - FLastX;
    YOffset := FLastY - AY; { Reversed since y-coordinates go from bottom to left }

    FLastX := AX;
    FLastY := AY;

    ProcessMouseMovement(XOffset, YOffset);
  end;
end;

procedure TCamera.ProcessMouseMovement(const AXOffset, AYOffset: Single;
  const AConstrainPitch: Boolean);
var
  XOff, YOff: Single;
begin
  XOff := AXOffset * FSensitivity;
  YOff := AYOffset * FSensitivity;

  FYaw := FYaw + XOff;
  FPitch := FPitch + YOff;

  if (AConstrainPitch) then
    { Make sure that when pitch is out of bounds, screen doesn't get flipped }
    FPitch := EnsureRange(FPitch, -89, 89);

  UpdateCameraVectors;
end;

procedure TCamera.ProcessMouseUp;
begin
  if (not FLookAround) then
  begin
    { Mouse/finger was pressed near edge of screen to emulate WASD keys.
      "Release" those keys now. }
    FKeyW := False;
    FKeyA := False;
    FKeyS := False;
    FKeyD := False;
  end;
  FLookAround := False;
end;

procedure TCamera.ProcessMouseWheel(const AWheelDelta: Integer);
begin
  FZoom := EnsureRange(FZoom - AWheelDelta, 1, 45);
end;

constructor TCamera.Create(const AViewWidth, AViewHeight: Integer;
  const APosition: TVector3; const AYaw, APitch: Single);
begin
  Create(AViewWidth, AViewHeight, APosition, Vector3(0, 1, 0), AYaw, APitch);
end;

procedure TCamera.UpdateCameraVectors;
{ Calculates the front vector from the Camera's (updated) Euler Angles }
var
  Front: TVector3;
  SinYaw, CosYaw, SinPitch, CosPitch: Single;
begin
  { Calculate the new Front vector }
  FastSinCos(Radians(FYaw), SinYaw, CosYaw);
  FastSinCos(Radians(FPitch), SinPitch, CosPitch);

  Front.X := CosYaw * CosPitch;
  Front.Y := SinPitch;
  Front.Z := SinYaw * CosPitch;

  FFront := Front.NormalizeFast;

  { Also re-calculate the Right and Up vector.
    Normalize the vectors, because their length gets closer to 0 the more you
    look up or down which results in slower movement. }
  FRight := FFront.Cross(FWorldUp).NormalizeFast;
  FUp := FRight.Cross(FFront).NormalizeFast;
end;

procedure TCamera.UpdateScreenEdge(const AViewWidth, AViewHeight: Single);
const
  EDGE_THRESHOLD = 0.15; // 15%
var
  ViewWidth, ViewHeight: Single;
begin
  { Set the screen edge thresholds based on the dimensions of the screen/view.
    These threshold are used to emulate WASD keys when a mouse/finger is
    pressed near the edge of the screen. }
  ViewWidth := AViewWidth / TPlatform.ScreenScale;
  ViewHeight := AViewHeight / TPlatform.ScreenScale;
  FScreenEdge.Left := EDGE_THRESHOLD * ViewWidth;
  FScreenEdge.Top := EDGE_THRESHOLD * ViewHeight;
  FScreenEdge.Right := (1 - EDGE_THRESHOLD) * ViewWidth;
  FScreenEdge.Bottom := (1 - EDGE_THRESHOLD) * ViewHeight;
end;

procedure TCamera.ViewResized(const AWidth, AHeight: Integer);
begin
  UpdateScreenEdge(AWidth, AHeight);
end;

function TCamera._GetFront: TVector3;
begin
  Result := FFront;
end;

function TCamera._GetMovementSpeed: Single;
begin
  Result := FMovementSpeed;
end;

function TCamera._GetPitch: Single;
begin
  Result := FPitch;
end;

function TCamera._GetPosition: TVector3;
begin
  Result := FPosition;
end;

function TCamera._GetRight: TVector3;
begin
  Result := FRight;
end;

function TCamera._GetSensitivity: Single;
begin
  Result := FSensitivity;
end;

function TCamera._GetUp: TVector3;
begin
  Result := FUp;
end;

function TCamera._GetWorldUp: TVector3;
begin
  Result := FWorldUp;
end;

function TCamera._GetYaw: Single;
begin
  Result := FYaw;
end;

function TCamera._GetZoom: Single;
begin
  Result := FZoom;
end;

procedure TCamera._SetFront(const AValue: TVector3);
begin
  FFront := AValue;
end;

procedure TCamera._SetMovementSpeed(const AValue: Single);
begin
  FMovementSpeed := AValue;
end;

procedure TCamera._SetPitch(const AValue: Single);
begin
  FPitch := AValue;
end;

procedure TCamera._SetPosition(const AValue: TVector3);
begin
  FPosition := AValue;
end;

procedure TCamera._SetRight(const AValue: TVector3);
begin
  FRight := AValue;
end;

procedure TCamera._SetSensitivity(const AValue: Single);
begin
  FSensitivity := AValue;
end;

procedure TCamera._SetUp(const AValue: TVector3);
begin
  FUp := AValue;
end;

procedure TCamera._SetWorldUp(const AValue: TVector3);
begin
  FWorldUp := AValue;
end;

procedure TCamera._SetYaw(const AValue: Single);
begin
  FYaw := AValue;
end;

procedure TCamera._SetZoom(const AValue: Single);
begin
  FZoom := AValue;
end;

end.
