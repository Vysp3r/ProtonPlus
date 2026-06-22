namespace ProtonPlus.Models.Launchers.Runners {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public enum RunnerType {
        DXVK,
        VKD3D,
        Proton,
        Wine,
    }

    public class Runners : Object {
        public Gee.HashMap<RunnerType, Gee.ArrayList<IRunner>> list { get; set; default = new Gee.HashMap<RunnerType, Gee.ArrayList<IRunner>> (); }

        public Runners () {
            this.list.set (RunnerType.DXVK, new Gee.ArrayList<IRunner> ());
            this.list.set (RunnerType.VKD3D, new Gee.ArrayList<IRunner> ());
            this.list.set (RunnerType.Proton, new Gee.ArrayList<IRunner> ());
            this.list.set (RunnerType.Wine, new Gee.ArrayList<IRunner> ());

            var dxvk_runners = new Gee.ArrayList<IRunner> ();
            dxvk_runners.add (new ProtonPlus.Models.Launchers.Runners.DXVK.Doitsujin ());
            dxvk_runners.add (new ProtonPlus.Models.Launchers.Runners.DXVK.Ph42on ());
            dxvk_runners.add (new ProtonPlus.Models.Launchers.Runners.DXVK.Sarek ());
            this.addMultipleDXVK (dxvk_runners);

            var vkd3d_runners = new Gee.ArrayList<IRunner> ();
            vkd3d_runners.add (new ProtonPlus.Models.Launchers.Runners.VKD3D.Lutris ());
            vkd3d_runners.add (new ProtonPlus.Models.Launchers.Runners.VKD3D.Proton ());
            this.addMultipleVKD3D (vkd3d_runners);

            var proton_runners = new Gee.ArrayList<IRunner> ();
            proton_runners.add (new ProtonPlus.Models.Launchers.Runners.Proton.Buxtron ());
            proton_runners.add (new ProtonPlus.Models.Launchers.Runners.Proton.DW ());
            proton_runners.add (new ProtonPlus.Models.Launchers.Runners.Proton.Luxtorpeda ());
            proton_runners.add (new ProtonPlus.Models.Launchers.Runners.Proton.CachyOS ());
            proton_runners.add (new ProtonPlus.Models.Launchers.Runners.Proton.ProtonEM ());
            proton_runners.add (new ProtonPlus.Models.Launchers.Runners.Proton.ProtonGE ());
            proton_runners.add (new ProtonPlus.Models.Launchers.Runners.Proton.ProtonGERtsp ());
            proton_runners.add (new ProtonPlus.Models.Launchers.Runners.Proton.ProtonTKG ());
            proton_runners.add (new ProtonPlus.Models.Launchers.Runners.Proton.Roberta ());
            this.addMultipleProton (proton_runners);

            var wine_runners = new Gee.ArrayList<IRunner> ();
            wine_runners.add (new ProtonPlus.Models.Launchers.Runners.Wine.Proton ());
            wine_runners.add (new ProtonPlus.Models.Launchers.Runners.Wine.Staging ());
            wine_runners.add (new ProtonPlus.Models.Launchers.Runners.Wine.StagingTkg ());
            wine_runners.add (new ProtonPlus.Models.Launchers.Runners.Wine.Vanilla ());
            this.addMultipleWine (wine_runners);
        }

        public void addDXVK (IRunner runner) {
            this.add (RunnerType.DXVK, runner);
        }

        public void addVKD3D (IRunner runner) {
            this.add (RunnerType.VKD3D, runner);
        }

        public void addProton (IRunner runner) {
            this.add (RunnerType.Proton, runner);
        }

        public void addWine (IRunner runner) {
            this.add (RunnerType.Wine, runner);
        }

        public void addMultipleDXVK (Gee.Iterable<IRunner> new_runners) {
            this.addMultiple (RunnerType.DXVK, new_runners);
        }

        public void addMultipleVKD3D (Gee.Iterable<IRunner> new_runners) {
            this.addMultiple (RunnerType.VKD3D, new_runners);
        }

        public void addMultipleProton (Gee.Iterable<IRunner> new_runners) {
            this.addMultiple (RunnerType.Proton, new_runners);
        }

        public void addMultipleWine (Gee.Iterable<IRunner> new_runners) {
            this.addMultiple (RunnerType.Wine, new_runners);
        }

        public Gee.ArrayList<IRunner> getDXVK () {
            return this.get (RunnerType.DXVK);
        }

        public Gee.ArrayList<IRunner> getVKD3D () {
            return this.get (RunnerType.VKD3D);
        }

        public Gee.ArrayList<IRunner> getProton () {
            return this.get (RunnerType.Proton);
        }

        public Gee.ArrayList<IRunner> getWine () {
            return this.get (RunnerType.Wine);
        }

        public Gee.ArrayList<IRunner> get (RunnerType type) {
            Gee.ArrayList<IRunner>? runners = this.list.get (type);

            if (runners == null) {
                runners = new Gee.ArrayList<IRunner> ();
                this.list.set (type, runners);
            }

            return runners;
        }

        public void add (RunnerType type, IRunner runner) {
            this.get (type).add (runner);
        }

        public void addMultiple (RunnerType type, Gee.Iterable<IRunner> new_runners) {
            foreach (var runner in new_runners) {
                this.add (type, runner);
            }
        }
    }
}
