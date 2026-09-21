namespace BuildsAndBosses;

public static class Program
{
	public static void Main()
	{
		using var game = new BuildsAndBossesGame();
		game.Run();
	}
}
