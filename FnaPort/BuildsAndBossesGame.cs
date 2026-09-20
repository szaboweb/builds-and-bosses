using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;

namespace BuildsAndBosses;

public sealed class BuildsAndBossesGame : Game
{
    private readonly GraphicsDeviceManager graphics;
    private SpriteBatch spriteBatch = null!;
    private Texture2D pixel = null!;
    private readonly CampaignProgression campaign = new();
    private readonly List<Vector2> projectiles = new();
    private MalakarData malakar = null!;
    private CharacterBlueprint blueprint = new();
    private GameScreen screen = GameScreen.Blueprint;
    private HeroLevelMode levelMode = HeroLevelMode.LevelUp;
    private KeyboardState previousKeys;
    private Vector2 heroPosition;
    private float heroVerticalSpeed;
    private float bossX;
    private float bossAttackTimer;
    private float spawnProtection;
    private float hitProtection;
    private int heroHp;
    private int bossHp;

    private enum GameScreen { Blueprint, Boss, Result }

    public BuildsAndBossesGame()
    {
        graphics = new GraphicsDeviceManager(this);
        graphics.PreferredBackBufferWidth = 1280;
        graphics.PreferredBackBufferHeight = 720;
        graphics.IsFullScreen = false;
        Content.RootDirectory = "Content";
        IsMouseVisible = true;
        Window.Title = "Builds & Bosses - FNA Port";
    }

    protected override void Initialize()
    {
        heroPosition = new Vector2(128, 520);
        malakar = DataFiles.LoadMalakar();
        base.Initialize();
    }

    protected override void LoadContent()
    {
        spriteBatch = new SpriteBatch(GraphicsDevice);
        pixel = new Texture2D(GraphicsDevice, 1, 1);
        pixel.SetData(new[] { Color.White });
    }

    protected override void Update(GameTime gameTime)
    {
        var dt = (float)gameTime.ElapsedGameTime.TotalSeconds;
        var keys = Keyboard.GetState();
        if (keys.IsKeyDown(Keys.Escape)) Exit();

        if (screen == GameScreen.Blueprint)
            UpdateBlueprint(keys);
        else if (screen == GameScreen.Boss)
            UpdateBoss(keys, dt);
        else if (Pressed(keys, Keys.Enter))
            ResetBlueprint();

        previousKeys = keys;
        base.Update(gameTime);
    }

    private void UpdateBlueprint(KeyboardState keys)
    {
        if (Pressed(keys, Keys.Q))
        {
            levelMode = levelMode == HeroLevelMode.LevelUp ? HeroLevelMode.LevelDown : HeroLevelMode.LevelUp;
            blueprint = new CharacterBlueprint();
        }
        var targetLevel = levelMode == HeroLevelMode.LevelDown
            ? campaign.Scaling.HeroLevelDown
            : campaign.Scaling.HeroLevelUp;
        if (Pressed(keys, Keys.Right) && blueprint.TotalLevel < targetLevel)
            blueprint.ClassLevels["fighter"] = blueprint.TotalLevel + 1;
        if (Pressed(keys, Keys.Left) && blueprint.ClassLevels.TryGetValue("fighter", out var level))
        {
            if (level <= 1) blueprint.ClassLevels.Remove("fighter");
            else blueprint.ClassLevels["fighter"] = level - 1;
        }
        if (Pressed(keys, Keys.Enter))
        {
            try
            {
                campaign.SelectBlueprint(blueprint, levelMode);
                heroHp = 80 + campaign.HeroLevel * 8;
                bossHp = malakar.stats.max_hp;
                bossX = 640;
                heroPosition = new Vector2(128, 520);
                spawnProtection = 1.5f;
                hitProtection = 0;
                bossAttackTimer = 1.0f;
                projectiles.Clear();
                screen = GameScreen.Boss;
            }
            catch (InvalidOperationException)
            {
                // The blueprint remains on screen until its target level is filled.
            }
        }
    }

    private void UpdateBoss(KeyboardState keys, float dt)
    {
        const float groundY = 520;
        var direction = (keys.IsKeyDown(Keys.D) || keys.IsKeyDown(Keys.Right) ? 1 : 0)
                      - (keys.IsKeyDown(Keys.A) || keys.IsKeyDown(Keys.Left) ? 1 : 0);
        heroPosition.X = MathHelper.Clamp(heroPosition.X + direction * 260 * dt, 80, 1200);
        if (Pressed(keys, Keys.W) && heroPosition.Y >= groundY) heroVerticalSpeed = -560;
        heroVerticalSpeed += 1500 * dt;
        heroPosition.Y = Math.Min(groundY, heroPosition.Y + heroVerticalSpeed * dt);

        spawnProtection = Math.Max(0, spawnProtection - dt);
        hitProtection = Math.Max(0, hitProtection - dt);
        bossAttackTimer -= dt;
        bossX += Math.Sign(heroPosition.X - bossX) * malakar.stats.speed * dt;

        if (Pressed(keys, Keys.Space) && Math.Abs(heroPosition.X - bossX) < 230)
            bossHp = Math.Max(0, bossHp - 12);
        if (bossHp == 0)
        {
            campaign.CompleteBoss();
            screen = GameScreen.Result;
            return;
        }

        if (bossAttackTimer <= 0)
        {
            bossAttackTimer = malakar.stats.attack_rate;
            if (Math.Abs(heroPosition.X - bossX) < 75)
                DamageHero(12);
            else
                projectiles.Add(new Vector2(bossX, 455));
        }
        for (var i = projectiles.Count - 1; i >= 0; i--)
        {
            projectiles[i] += new Vector2(Math.Sign(heroPosition.X - projectiles[i].X) * malakar.projectile.speed * dt, 0);
            if (Math.Abs(projectiles[i].X - heroPosition.X) < 24)
            {
                DamageHero(6);
                projectiles.RemoveAt(i);
            }
            else if (projectiles[i].X < 40 || projectiles[i].X > 1240)
                projectiles.RemoveAt(i);
        }
    }

    private void DamageHero(int amount)
    {
        if (spawnProtection > 0 || hitProtection > 0) return;
        heroHp = Math.Max(0, heroHp - amount);
        hitProtection = 0.65f;
        if (heroHp == 0) screen = GameScreen.Result;
    }

    protected override void Draw(GameTime gameTime)
    {
        GraphicsDevice.Clear(new Color(15, 17, 26));
        spriteBatch.Begin(
            SpriteSortMode.Deferred,
            BlendState.AlphaBlend,
            SamplerState.PointClamp,
            DepthStencilState.None,
            RasterizerState.CullCounterClockwise);
        if (screen == GameScreen.Blueprint) DrawBlueprint();
        else DrawBoss();
        spriteBatch.End();
        base.Draw(gameTime);
    }

    private void DrawBlueprint()
    {
        Fill(new Rectangle(120, 90, 1040, 520), new Color(25, 28, 42));
        Fill(new Rectangle(160, 160, 420, 330), new Color(45, 38, 60));
        Fill(new Rectangle(620, 160, 420, 330), new Color(32, 52, 62));
        Fill(new Rectangle(190, 390, 90 + blueprint.TotalLevel * 70, 24), Color.Goldenrod);
        Fill(new Rectangle(190, 530, 420, 16), levelMode == HeroLevelMode.LevelUp ? Color.Green : Color.Red);
        Fill(new Rectangle(650, 390, 260, 24), Color.Purple);
    }

    private void DrawBoss()
    {
        Fill(new Rectangle(0, 540, 1280, 180), new Color(25, 28, 42));
        Fill(new Rectangle(0, 520, 1280, 20), new Color(70, 70, 85));
        Fill(new Rectangle((int)heroPosition.X - 24, (int)heroPosition.Y - 48, 48, 48), Color.CornflowerBlue);
        Fill(new Rectangle((int)bossX - 40, 120, 80, 80), Color.MediumPurple);
        Fill(new Rectangle(30, 30, Math.Max(0, heroHp) * 3, 18), Color.Red);
        Fill(new Rectangle(900, 30, Math.Max(0, bossHp) * 2, 18), Color.Purple);
        foreach (var projectile in projectiles)
            Fill(new Rectangle((int)projectile.X - 8, (int)projectile.Y - 8, 16, 16), Color.Magenta);
    }

    private void Fill(Rectangle rectangle, Color color) => spriteBatch.Draw(pixel, rectangle, color);
    private bool Pressed(KeyboardState keys, Keys key) => keys.IsKeyDown(key) && !previousKeys.IsKeyDown(key);
    private void ResetBlueprint()
    {
        campaign.GetType();
        blueprint = new CharacterBlueprint();
        screen = GameScreen.Blueprint;
    }
}
