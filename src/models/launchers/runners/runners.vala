namespace ProtonPlus.Models.Launchers.Runners {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;
    using ProtonPlus.Models.Launchers.Runners;

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
            dxvk_runners.add (new DXVK.Doitsujin ());
            dxvk_runners.add (new DXVK.Ph42on ());
            dxvk_runners.add (new DXVK.Sarek ());
            this.addMultipleDXVK (dxvk_runners);

            var vkd3d_runners = new Gee.ArrayList<IRunner> ();
            vkd3d_runners.add (new VKD3D.Lutris ());
            vkd3d_runners.add (new VKD3D.Proton ());
            this.addMultipleVKD3D (vkd3d_runners);

            var proton_runners = new Gee.ArrayList<IRunner> ();
            proton_runners.add (new Proton.Buxtron ());
            proton_runners.add (new Proton.DW ());
            proton_runners.add (new Proton.Luxtorpeda ());
            proton_runners.add (new Proton.CachyOS ());
            proton_runners.add (new Proton.ProtonEM ());
            proton_runners.add (new Proton.ProtonGE ());
            proton_runners.add (new Proton.ProtonGERtsp ());
            proton_runners.add (new Proton.ProtonTKG ());
            proton_runners.add (new Proton.Roberta ());
            this.addMultipleProton (proton_runners);

            var wine_runners = new Gee.ArrayList<IRunner> ();
            wine_runners.add (new Wine.Proton ());
            wine_runners.add (new Wine.Staging ());
            wine_runners.add (new Wine.StagingTkg ());
            wine_runners.add (new Wine.Vanilla ());
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
            return this.getRunners (RunnerType.DXVK);
        }

        public Gee.ArrayList<IRunner> getVKD3D () {
            return this.getRunners (RunnerType.VKD3D);
        }

        public Gee.ArrayList<IRunner> getProton () {
            return this.getRunners (RunnerType.Proton);
        }

        public Gee.ArrayList<IRunner> getWine () {
            return this.getRunners (RunnerType.Wine);
        }

        public Gee.ArrayList<IRunner> getRunners (RunnerType type) {
            Gee.ArrayList<IRunner>? runners = this.list.get (type);

            if (runners == null) {
                runners = new Gee.ArrayList<IRunner> ();
                this.list.set (type, runners);
            }

            return runners;
        }

        public void add (RunnerType type, IRunner runner) {
            this.getRunners (type).add (runner);
        }

        public void addMultiple (RunnerType type, Gee.Iterable<IRunner> new_runners) {
            foreach (var runner in new_runners) {
                this.add (type, runner);
            }
        }
    }
}
