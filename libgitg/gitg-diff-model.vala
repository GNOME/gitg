public class Gitg.DiffModel: Object {

  public enum DiffType {
    ADD,
    MODIFIED,
    REMOVED
  }
  public enum Direction {
      RTL,
      LTR
  }
  public signal void removed ();

  public int f0 { get; set; }
  public int f1 { get; set; }
  public int t0 { get; set; }
  public int t1 { get; set; }
  public DiffType diff_type { get; set; }
  public Direction direction { get; set; }
}
