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

implementation

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
