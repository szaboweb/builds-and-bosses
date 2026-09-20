using System.Text.Json;

namespace BuildsAndBosses;

public enum HeroLevelMode { LevelDown, LevelUp }
public enum CampaignPhase { Blueprint, Boss, Complete }

public readonly record struct BossScaling(int BossNumber, int HeroLevelDown, int HeroLevelUp, int BossLevel);

public static class CampaignMatrix
{
    public static readonly BossScaling[] Rows =
    {
        new(1, 1, 2, 4), new(2, 2, 4, 6), new(3, 4, 6, 8),
        new(4, 6, 8, 10), new(5, 8, 10, 12), new(6, 10, 12, 14),
        new(7, 12, 14, 16), new(8, 14, 16, 18), new(9, 16, 18, 20),
        new(10, 18, 20, 22), new(11, 18, 20, 24),
    };
}

public sealed class CharacterBlueprint
{
    public string Name { get; set; } = "Hero";
    public Dictionary<string, int> ClassLevels { get; } = new();
    public int TotalLevel => ClassLevels.Values.Sum();

    public void Validate(int expectedLevel)
    {
        if (string.IsNullOrWhiteSpace(Name))
            throw new InvalidOperationException("Blueprint name cannot be empty.");
        if (ClassLevels.Count is < 1 or > 3)
            throw new InvalidOperationException("A blueprint must use 1-3 classes.");
        if (ClassLevels.Any(pair => pair.Value < 1))
            throw new InvalidOperationException("Class levels must be positive.");
        if (TotalLevel != expectedLevel)
            throw new InvalidOperationException($"Expected level {expectedLevel}, got {TotalLevel}.");
    }
}

public sealed class CampaignProgression
{
    public int BossNumber { get; private set; } = 1;
    public CampaignPhase Phase { get; private set; } = CampaignPhase.Blueprint;
    public HeroLevelMode LevelMode { get; private set; } = HeroLevelMode.LevelUp;
    public CharacterBlueprint? Blueprint { get; private set; }
    public BossScaling Scaling => CampaignMatrix.Rows[BossNumber - 1];
    public int HeroLevel => LevelMode == HeroLevelMode.LevelDown ? Scaling.HeroLevelDown : Scaling.HeroLevelUp;

    public void SelectBlueprint(CharacterBlueprint blueprint, HeroLevelMode mode)
    {
        LevelMode = mode;
        blueprint.Validate(HeroLevel);
        Blueprint = blueprint;
        Phase = CampaignPhase.Boss;
    }

    public void CompleteBoss()
    {
        if (Phase != CampaignPhase.Boss)
            throw new InvalidOperationException("The boss fight is not active.");
        Phase = CampaignPhase.Complete;
    }
}

public sealed class MalakarData
{
    public string id { get; set; } = "boss_001_malakar";
    public string name { get; set; } = "Gravekeeper Malakar";
    public BossStats stats { get; set; } = new();
    public BossSpawn spawn { get; set; } = new();
    public BossProjectileData projectile { get; set; } = new();
}

public sealed class BossStats
{
    public int max_hp { get; set; }
    public int armor_class { get; set; }
    public float speed { get; set; }
    public float attack_rate { get; set; }
    public int attack_bonus { get; set; }
    public int damage_die { get; set; }
    public int damage_count { get; set; }
}

public sealed class BossSpawn
{
    public float x_pct { get; set; } = 0.5f;
    public float y_px { get; set; } = 130;
}

public sealed class BossProjectileData
{
    public float speed { get; set; } = 240;
    public int radius { get; set; } = 10;
    public int damage_die { get; set; } = 6;
    public int damage_count { get; set; } = 1;
}

public static class DataFiles
{
    public static MalakarData LoadMalakar()
    {
        var path = Path.Combine(AppContext.BaseDirectory, "data", "bosses", "boss_001_malakar.json");
        return JsonSerializer.Deserialize<MalakarData>(File.ReadAllText(path))
            ?? throw new InvalidOperationException("Could not load Malakar data.");
    }
}
