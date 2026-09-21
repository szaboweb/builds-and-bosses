using Godot;

public partial class GameRoot : Node2D
{
    private Label _title;

    public override void _Ready()
    {
        GD.Print("Builds & Bosses - Godot C# booted");

        _title = GetNode<Label>("Title");
        if (_title != null)
        {
            _title.Text = "Builds & Bosses";
        }
    }

    public override void _Process(double delta)
    {
        // Temporary bootstrapping placeholder for the C# Godot project.
    }
}
