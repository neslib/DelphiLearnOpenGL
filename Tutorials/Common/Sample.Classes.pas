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
  System.Generics.Collections,
  System.Generics.Defaults,
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
    function GetUniformLocationUnicode(const AName: String): Integer;

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
    function GetUniformLocationUnicode(const AName: String): Integer;
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
        AOptional: (optional) if set to True, the attribute is ignored if it
          doesn't exist in the shader. Otherwise, an exception is raised if the
          attribute is not found.

      Returns:
        This instance, for use in a fluent API. }
    function Add(const AName: RawByteString; const ACount: Integer;
      const ANormalized: Boolean = False;
      const AOptional: Boolean = False): PVertexLayout;
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
  { Implements ICamera }
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
    { ICamera }
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

type
  { Class for parsing .OBJ and .MTL files }
  TParser = class
  {$REGION 'Internal Declarations'}
  private
    FData: String;
    FCurrent: PChar;
  {$ENDREGION 'Internal Declarations'}
  public
    { Creates a parser.

      Parameters:
        APath: path into the assets.zip file containing the file to parse
          (eg. 'models/MyModel.obj'). }
    constructor Create(const APath: String);

    { Parses a line in the file.

      Parameters:
        ACommand: is set to command that starts the line (first word in the
          string).
        AArg1: is set to the first argument of the command
        AArg2: is set to the second argument of the command (if any)
        AArg3: is set to the third argument of the command (if any)

      Returns:
        True if a line was parsed, or False if the end of the file has been
        reached.

      This method will ignore empty lines and comments. }
    function ReadLine(out ACommand, AArg1, AArg2, AArg3: String): Boolean;
  end;

type
  { Vertex type used to render 3D models (see TMesh, IModel) }
  TVertex = record
  public
    Position: TVector3;
    Normal: TVector3;
    TexCoords: TVector2;
  end;

type
  { The kind of a TTexture map }
  TTextureKind = (Diffuse, Specular, Normal, Height);

type
  { Represents a texture (map) as used by a TMesh }
  TTexture = record
  {$REGION 'Internal Declarations'}
  private
    FId: GLuint;
    FKind: TTextureKind;
  {$ENDREGION 'Internal Declarations'}
  public
    { Loads the texture from a file in assets.zip.

      Parameters:
        APath: path into the assets.zip file containing the image file
          (eg. 'models/MyModelTexture.jpg').
        AKind: the kind of texture this is. }
    procedure Load(const APath: String;
      const AKind: TTextureKind);

    { OpenGL id of texture }
    property Id: GLuint read FId;

    { Kind of texture }
    property Kind: TTextureKind read FKind;
  end;

type
  { Represents a 3D mesh in a IModel/TModel }
  TMesh = class
  {$REGION 'Internal Declarations'}
  private
    FShader: IShader;
    FVertices: TArray<TVertex>;
    FIndices: TArray<UInt16>;
    FTextures: TArray<TTexture>;
    FVertexArray: IVertexArray;
  private
    procedure SetupMesh;
  {$ENDREGION 'Internal Declarations'}
  public
    { Creates a mesh.

      Parameters:
        AVertices: the vertices that make up the mesh
        AIndices: indices into to vertices that define the mesh triangles
        ATextures: texture (maps) used to render the mesh
        AShader: the shader used to render the mesh. }
    constructor Create(const AVertices: TArray<TVertex>;
      const AIndices: TArray<UInt16>; const ATextures: TArray<TTexture>;
      const AShader: IShader);

    { Draws/renders the mesh }
    procedure Draw;
  end;

type
  { Represents a 3D model, loaded from a Wavefront .OBJ resource.
    Implemented in the TModel class. }
  IModel = interface
  ['{29B5AB25-129C-4CA6-B368-146577F298F6}']
    { Draws/renders the model }
    procedure Draw;
  end;

type
  { Implements IModel }
  TModel = class(TInterfacedObject, IModel)
  {$REGION 'Internal Declarations'}
  private type
    { Temporary record used to store material properties }
    TMaterial = record
    public
      DiffuseMaps: TArray<String>;
      SpecularMaps: TArray<String>;
      NormalMaps: TArray<String>;
      HeightMaps: TArray<String>;
    public
      procedure Clear;
    end;
  private type
    { Vertex type to define faces in a OBJ file }
    TFaceVertex = packed record
      { Index into the array of positions }
      PositionIndex: UInt16;

      { Index into the array of normals }
      NormalIndex: UInt16;

      { Index into the array of texture coordinates }
      TexCoordIndex: UInt16;
    end;
  private type
    { Light-weight and fast list }
    TFastList<T: record> = record
    private
      FItems: TArray<T>;
      FCapacity: Integer;
      FCount: Integer;
    public
      { Initializes to empty list.

        Parameters:
          ACapacity: (optional) initial capacity of the list }
      procedure Init(const ACapacity: Integer = 256);

      { Adds an item }
      procedure Add(const AItem: T);

      { Clears the list }
      procedure Clear;

      { Convert list to array }
      function ToArray: TArray<T>;

      { Number of items in the list }
      property Count: Integer read FCount;
    end;
  private
    FMeshes: TObjectList<TMesh>;

    { Stores all the textures loaded so far (by lowercase path).
      Used as optimization to make sure textures aren't loaded more than once. }
    FLoadedTextures: TDictionary<String, TTexture>;

    FDirectory: String;
    FShader: IShader;
  private
    procedure LoadModel(const APath: String);
    procedure LoadMtlLib(const APath: String;
      const AMaterials: TDictionary<String, TMaterial>);
    procedure ParseOBJ(const AParser: TParser);
    procedure ParseMTL(const AParser: TParser;
      const AMaterials: TDictionary<String, TMaterial>);
    function LoadMaterialTexture(const AFilename: String;
      const AKind: TTextureKind): TTexture;
  private
    class function ToVector2(const AX, AY: String): TVector2; inline; static;
    class function ToVector3(const AX, AY, AZ: String): TVector3; inline; static;
    class function ToFaceVertex(const AString: String): TFaceVertex; static;
  protected
    { IModel }
    procedure Draw;
  {$ENDREGION 'Internal Declarations'}
  public
    { Creates a model.

      Parameters:
        APath: path into the assets.zip file containing the Wavefront .OBJ
          file (eg. 'models/MyModel.obj').
        AShader: the shader used to render the model.

      If the model file references any external resources such as textures or
      material libraries, then they must be in the same directory as the .OBJ
      file. }
    constructor Create(const APath: String; const AShader: IShader);
    destructor Destroy; override;
  end;

var
  { Format settings that handle US-style presentation of numbers. }
  USFormatSettings: TFormatSettings;

{ Helper function to determine if a value is a power of two.

  Parameters:
    AValue: the value to check.

  Returns:
    True if AValue is a power of 2, or False otherwise. }
function IsPowerOfTwo(const AValue: Cardinal): Boolean; inline;

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
  System.IOUtils,
  {$IF Defined(MACOS)}
  Macapi.CoreFoundation, // For inlining to work
  {$ELSEIF Defined(ANDROID)}
  Posix.Dlfcn,
  {$ENDIF}
  Neslib.Stb.Image,
  Sample.Platform;

function IsPowerOfTwo(const AValue: Cardinal): Boolean; inline;
begin
  { https://graphics.stanford.edu/~seander/bithacks.html#DetermineIfPowerOf2 }
  Result := ((AValue and (AValue - 1)) = 0);
end;

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

function TShader.GetUniformLocationUnicode(const AName: String): Integer;
begin
  Result := GetUniformLocation(RawByteString(AName));
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
  const ANormalized, AOptional: Boolean): PVertexLayout;
var
  Location, Stride: Integer;
begin
  if (FAttributeCount = MAX_ATTRIBUTES) then
    raise Exception.Create('Too many attributes in vertex layout');

  Stride := FStride + (ACount * SizeOf(Single));
  if (Stride >= 256) then
    raise Exception.Create('Vertex layout too big');

  Location := glGetAttribLocation(FProgram, MarshaledAString(AName));
  if (Location < 0) and (not AOptional) then
    raise Exception.CreateFmt('Attribute "%s" not found in shader', [AName]);

  if (Location >= 0) then
  begin
    Assert(Location <= 255);
    FAttributes[FAttributeCount].Location := Location;
    FAttributes[FAttributeCount].Size := ACount;
    FAttributes[FAttributeCount].Normalized := Ord(ANormalized);
    FAttributes[FAttributeCount].Offset := FStride;
    Inc(FAttributeCount);
  end;

  FStride := Stride;

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

{ TParser }

constructor TParser.Create(const APath: String);
var
  Data: TBytes;
  Encoding: TEncoding;
  PreambleLength: Integer;
begin
  inherited Create;
  Data := TAssets.Load(APath);

  { Try to determine encoding of file }
  Encoding := nil;
  PreambleLength := TEncoding.GetBufferEncoding(Data, Encoding);

  { Convert to UnicodeString }
  FData := Encoding.GetString(Data, PreambleLength, Length(Data) - PreambleLength);
  FCurrent := PChar(FData);
end;

function TParser.ReadLine(out ACommand, AArg1, AArg2, AArg3: String): Boolean;
var
  P: PChar;

  function ParseString: String;
  var
    Start: PChar;
  begin
    if (P^ = #0) or (P^ = #10) then
      { End of line/file }
      Exit('');

    Start := P;

    { Advance to next whitespace }
    while (P^ > ' ') do
      Inc(P);

    { Extract string }
    SetString(Result, Start, P - Start);

    { Skip whitespace }
    while (P^ = #9) or (P^ = #13) or (P^ = ' ') do
      Inc(P);
  end;

begin
  P := FCurrent;

  { Repeat until line has been read or end of file has been reached }
  while True do
  begin
    { Skip whitespace }
    while (P^ <> #0) and (P^ <= ' ') do
      Inc(P);

    if (P^ = #0) then
    begin
      { End of file reached }
      FCurrent := P;
      Exit(False);
    end;

    if (P^ = '#') then
    begin
      { Ignore comment }
      Inc(P);
      while (P^ <> #0) and (P^ <> #10) do
        Inc(P);

      { Next line }
      Continue;
    end;

    ACommand := ParseString;
    AArg1 := ParseString;
    AArg2 := ParseString;
    AArg3 := ParseString;
    FCurrent := P;
    Exit(True);
  end;
end;

{ TTexture }

procedure TTexture.Load(const APath: String; const AKind: TTextureKind);
var
  Width, Height, Components: Integer;
  Data: TBytes;
  Image: Pointer;
  SupportsMipmaps: Boolean;
begin
  FKind := AKind;

  { Generate OpenGL texture }
  glGenTextures(1, @FId);
  glBindTexture(GL_TEXTURE_2D, FId);

  { Load texture }
  Data := TAssets.Load(APath);
  Assert(Assigned(Data));
  Image := stbi_load_from_memory(Data, Length(Data), Width, Height, Components, 3);
  Assert(Assigned(Image));

  { Set texture data }
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, Width, Height, 0, GL_RGB, GL_UNSIGNED_BYTE, Image);

  { Generate mipmaps if possible. With OpenGL ES, mipmaps are only supported
    if both dimensions are a power of two. }
  SupportsMipmaps := IsPowerOfTwo(Width) and IsPowerOfTwo(Height);
  if (SupportsMipmaps) then
    glGenerateMipmap(GL_TEXTURE_2D);

  { Set texture parameters }
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);

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

{ TMesh }

constructor TMesh.Create(const AVertices: TArray<TVertex>;
  const AIndices: TArray<UInt16>; const ATextures: TArray<TTexture>;
  const AShader: IShader);
begin
  inherited Create;
  FShader := AShader;
  FVertices := AVertices;
  FIndices := AIndices;
  FTextures := ATextures;

  { Now that we have all the required data, set the vertex buffers and its
    attribute pointers. }
  SetupMesh;
end;

procedure TMesh.Draw;
var
  Prog, DiffuseNr, SpecularNr, NormalNr, HeightNr, Nr: GLuint;
  Location: GLint;
  I: Integer;
  Name: RawByteString;
begin
  { Bind appropriate textures }
  Prog := FShader.Handle;
  DiffuseNr := 1;
  SpecularNr := 1;
  NormalNr := 1;
  HeightNr := 1;
  for I := 0 to Length(FTextures) - 1 do
  begin
    { Active proper texture unit before binding }
    glActiveTexture(GL_TEXTURE0 + I);

    { Retrieve texture number (the N in diffuse_textureN) }
    case FTextures[I].Kind of
      TTextureKind.Diffuse:
        begin
          Name := 'texture_diffuse';
          Nr := DiffuseNr;
          Inc(DiffuseNr);
        end;

      TTextureKind.Specular:
        begin
          Name := 'texture_specular';
          Nr := SpecularNr;
          Inc(SpecularNr);
        end;

      TTextureKind.Normal:
        begin
          Name := 'texture_normal';
          Nr := NormalNr;
          Inc(NormalNr);
        end;

      TTextureKind.Height:
        begin
          Name := 'texture_height';
          Nr := HeightNr;
          Inc(HeightNr);
        end;
    else
      Assert(False);
      Nr := 0;
    end;

    if (Nr > 0) then
    begin
      { Now set the sampler to the correct texture unit }
      Name := Name + UTF8Char(Ord('0') + Nr);
      Location := glGetUniformLocation(Prog, MarshaledAString(Name));
      if (Location >= 0) then
      begin
        glUniform1i(Location, I);

        { And finally bind the texture }
        glBindTexture(GL_TEXTURE_2D, FTextures[I].Id);
      end;
    end;
  end;

  { Draw the mesh }
  FVertexArray.Render;

  { Always good practice to set everything back to defaults once configured. }
  for I := 0 to Length(FTextures) - 1 do
  begin
    glActiveTexture(GL_TEXTURE0 + I);
    glBindTexture(GL_TEXTURE_2D, 0);
  end;
  glErrorCheck;
end;

procedure TMesh.SetupMesh;
var
  VertexLayout: TVertexLayout;
begin
  { Create vertex layout to match TVertex type }
  VertexLayout.Start(FShader)
    .Add('position', 3)
    .Add('normal', 3, False, True)
    .Add('texCoords', 2, False, True);

  { Create vertex array (VAO, VBO and EBO) }
  FVertexArray := TVertexArray.Create(VertexLayout,
    FVertices[0], Length(FVertices) * SizeOf(TVertex), FIndices);
end;

{ TModel }

constructor TModel.Create(const APath: String; const AShader: IShader);
begin
  inherited Create;
  FShader := AShader;
  FMeshes := TObjectList<TMesh>.Create;
  FLoadedTextures := TDictionary<String, TTexture>.Create;
  LoadModel(APath);
end;

destructor TModel.Destroy;
begin
  FLoadedTextures.Free;
  FMeshes.Free;
  inherited;
end;

procedure TModel.Draw;
var
  I: Integer;
begin
  for I := 0 to FMeshes.Count - 1 do
    FMeshes[I].Draw;
end;

function TModel.LoadMaterialTexture(const AFilename: String;
  const AKind: TTextureKind): TTexture;
var
  LowerFilename: String;
begin
  { Check if texture was loaded before and if so, return existing texture }
  LowerFilename := AFilename.ToLower;
  if (FLoadedTextures.TryGetValue(LowerFilename, Result)) then
    Exit;

  Result.Load(FDirectory + AFilename, AKind);
  FLoadedTextures.Add(LowerFilename, Result);
end;

procedure TModel.LoadModel(const APath: String);
var
  Parser: TParser;
begin
  FDirectory := TPath.GetDirectoryName(APath) + '/';
  Parser := TParser.Create(APath);
  try
    ParseOBJ(Parser);
  finally
    Parser.Free;
  end;
end;

procedure TModel.LoadMtlLib(const APath: String;
  const AMaterials: TDictionary<String, TMaterial>);
var
  Parser: TParser;
begin
  Parser := TParser.Create(FDirectory + APath);
  try
    ParseMTL(Parser, AMaterials);
  finally
    Parser.Free;
  end;
end;

procedure TModel.ParseMTL(const AParser: TParser;
  const AMaterials: TDictionary<String, TMaterial>);
var
  Command, Arg1, Arg2, Arg3, MaterialName: String;
  Material: TMaterial;
begin
  MaterialName := '';
  while AParser.ReadLine(Command, Arg1, Arg2, Arg3) do
  begin
    if (Command = 'newmtl') then
    begin
      { Start a new material.
        Store previous material if any. }
      if (MaterialName <> '') then
        AMaterials.Add(MaterialName, Material);

      if (Arg1 = '') then
        raise Exception.Create('newmtl command requires a material name');

      MaterialName := Arg1;
      Material.Clear;
    end
    else if (Command.StartsWith('map_')) then
    begin
      { We only care about the "map_*" commands }
      if (Arg1 = '') then
        raise Exception.Create(Command + ' command requires a map file');

      if (Command = 'map_Kd') then
        Material.DiffuseMaps := Material.DiffuseMaps + [Arg1]
      else if (Command = 'map_Ks') then
        Material.SpecularMaps := Material.SpecularMaps + [Arg1]
      else if (Command = 'map_Bump') then
        Material.NormalMaps := Material.NormalMaps + [Arg1]
      else if (Command = 'map_Ka') then
        Material.HeightMaps := Material.HeightMaps + [Arg1];
    end;
  end;

  { Add last material }
  if (MaterialName <> '') then
    AMaterials.Add(MaterialName, Material);
end;

procedure TModel.ParseOBJ(const AParser: TParser);
var
  Command, Arg1, Arg2, Arg3, Filename: String;
  Materials: TDictionary<String, TMaterial>;
  Positions: TFastList<TVector3>;
  Normals: TFastList<TVector3>;
  TexCoords: TFastList<TVector2>;
  FaceVerts: TFastList<TFaceVertex>;
  Textures: TFastList<TTexture>;
  Material: TMaterial;
  TexCoord: TVector2;

  procedure StoreMesh;
  var
    Mesh: TMesh;
    V, Vn: TArray<TVector3>;
    Vt: TArray<TVector2>;
    F: TArray<TFaceVertex>;
    Vertices: TArray<TVertex>;
    Indices: TArray<UInt16>;
    I: Integer;
  begin
    if (Positions.Count = 0) or (FaceVerts.Count = 0) then
      Exit;

    { Convert positions, normals and texture coordinates to TVertex records.
      Note that the number of normals and texture coordinates does not have to
      match the number of positions. What positions, normals and texcoord belong
      to what vertex is determined by the FaceVerts array. }
    V := Positions.ToArray;
    Vn := Normals.ToArray;
    Vt := TexCoords.ToArray;
    F := FaceVerts.ToArray;

    { F contains 3 vertices for each triangle. Each vertex defines the indices
      into the V, Vn and Vt arrays.

      Use these to create an array of TVertex vertices and an array of indices.
      Since we use 16-bit indices in these tutorials, the F array may contain
      no more than 65,536 elements. }
    if (Length(F) > 65536) then
      raise Exception.Create('Too many vertices in mesh');

    { Note: we could optimize the creation of the vertex array here by checking
      for duplicate face vertices in the F array and sharing those vertices.
      However, we keep it simple here and convert each TFaceVertex to a TVertex
      and create a simple sequential array of indices. }
    SetLength(Vertices, Length(F));
    SetLength(Indices, Length(F));
    for I := 0 to Length(F) - 1 do
    begin
      Assert(F[I].PositionIndex < Length(V));
      Assert(F[I].TexCoordIndex < Length(Vt));
      Assert(F[I].NormalIndex < Length(Vn));

      Indices[I] := I;
      Vertices[I].Position := V[F[I].PositionIndex];
      Vertices[I].Normal := Vn[F[I].NormalIndex];
      Vertices[I].TexCoords := Vt[F[I].TexCoordIndex];
    end;

    Mesh := TMesh.Create(Vertices, Indices, Textures.ToArray, FShader);
    FMeshes.Add(Mesh);
  end;

begin
  Positions.Init;
  Normals.Init;
  TexCoords.Init;
  FaceVerts.Init;
  Textures.Init(4);

  Materials := TDictionary<String, TMaterial>.Create;
  try
    while AParser.ReadLine(Command, Arg1, Arg2, Arg3) do
    begin
      { We ignore unknown commands }
      case Command.Chars[0] of
        'f': if (Command = 'f') then
             begin
               { Define a face. Each argument is in the format:
                   v/vt/vn
                 Where:
                 * v: 1-based index into Positions list
                 * vt: 1-based index into TexCoords list
                 * vn: 1-based index into Normals list
                 Note that we subtract 1 from each value so indices start at 0. }
               FaceVerts.Add(ToFaceVertex(Arg1));
               FaceVerts.Add(ToFaceVertex(Arg2));
               FaceVerts.Add(ToFaceVertex(Arg3));
             end;

        'm': if (Command = 'mtllib') then
               LoadMtlLib(Arg1, Materials);

        'o': if (Command = 'o') then
             begin
               { Start a new object/mesh. Store previous mesh if any. }
               StoreMesh;
               FaceVerts.Clear;
               Textures.Clear;

               { Don't clear Positions, Normals and TexCoords. The 'f' command
                 indexes these as global lists that should not be cleared until
                 the entire file has been read. }
             end;

        'u': if (Command = 'usemtl') then
             begin
               { Assign material from material library to mesh. }
               if (not Materials.TryGetValue(Arg1, Material)) then
                 raise Exception.CreateFmt('Material "%s" not found in material library', [Arg1]);

               for Filename in Material.DiffuseMaps do
                 Textures.Add(LoadMaterialTexture(Filename, TTextureKind.Diffuse));

               for Filename in Material.SpecularMaps do
                 Textures.Add(LoadMaterialTexture(Filename, TTextureKind.Specular));

               for Filename in Material.NormalMaps do
                 Textures.Add(LoadMaterialTexture(Filename, TTextureKind.Normal));

               for Filename in Material.HeightMaps do
                 Textures.Add(LoadMaterialTexture(Filename, TTextureKind.Height));
             end;

        'v': if (Command = 'v') then
               { Add position }
               Positions.Add(ToVector3(Arg1, Arg2, Arg3))
             else if (Command = 'vt') then
             begin
               { Add texture coordinate }
               TexCoord := ToVector2(Arg1, Arg2);
               { Flip Y coordinate to make texture align with OpenGL }
               TexCoord.Y := 1 - TexCoord.Y;
               TexCoords.Add(TexCoord);
             end
             else if (Command = 'vn') then
               { Add normal }
               Normals.Add(ToVector3(Arg1, Arg2, Arg3));
      end;
    end;
  finally
    Materials.Free;
  end;

  { Store last mesh }
  StoreMesh;
end;

class function TModel.ToFaceVertex(const AString: String): TFaceVertex;
var
  P, Start: PChar;
  S: String;
begin
  if (AString = '') then
    raise Exception.Create('Invalid face vertex');

  { Parse v/vt/vn in its parts }
  P := Pointer(AString);

  { Parse v }
  Start := P;
  while (P^ <> '/') and (P^ <> #0) do
    Inc(P);
  if (P^ = #0) then
    raise Exception.Create('Invalid face vertex');
  SetString(S, Start, P - Start);
  Result.PositionIndex := StrToInt(S) - 1;
  Inc(P);

  { Parse vt }
  Start := P;
  while (P^ <> '/') and (P^ <> #0) do
    Inc(P);
  if (P^ = #0) then
    raise Exception.Create('Invalid face vertex');
  SetString(S, Start, P - Start);
  Result.TexCoordIndex := StrToInt(S) - 1;
  Inc(P);

  { Parse vn }
  Start := P;
  while (P^ <> #0) do
    Inc(P);
  SetString(S, Start, P - Start);
  Result.NormalIndex := StrToInt(S) - 1;
end;

class function TModel.ToVector2(const AX, AY: String): TVector2;
begin
  Result.X := StrToFloat(AX, USFormatSettings);
  Result.Y := StrToFloat(AY, USFormatSettings);
end;

class function TModel.ToVector3(const AX, AY, AZ: String): TVector3;
begin
  Result.X := StrToFloat(AX, USFormatSettings);
  Result.Y := StrToFloat(AY, USFormatSettings);
  Result.Z := StrToFloat(AZ, USFormatSettings);
end;

{ TModel.TMaterial }

procedure TModel.TMaterial.Clear;
begin
  DiffuseMaps := nil;
  SpecularMaps := nil;
  NormalMaps := nil;
  HeightMaps := nil;
end;

{ TModel.TFastList<T> }

procedure TModel.TFastList<T>.Add(const AItem: T);
begin
  if (FCount >= FCapacity) then
  begin
    FCapacity := FCapacity * 2;
    SetLength(FItems, FCapacity);
  end;
  FItems[FCount] := AItem;
  Inc(FCount);
end;

procedure TModel.TFastList<T>.Clear;
begin
  FCount := 0;
end;

procedure TModel.TFastList<T>.Init(const ACapacity: Integer = 256);
begin
  FCapacity := ACapacity;
  FCount := 0;
  SetLength(FItems, FCapacity);
end;

function TModel.TFastList<T>.ToArray: TArray<T>;
begin
  Result := FItems;
  SetLength(Result, FCount);
end;

initialization
  USFormatSettings := TFormatSettings.Create('en-US');
  USFormatSettings.ThousandSeparator := ',';
  USFormatSettings.DecimalSeparator := '.';

end.
