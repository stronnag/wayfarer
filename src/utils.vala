namespace Utils {
	public void get_even(ref int v, bool up = false) {
        if (up)
            v++;
        v&= ~1;
	}
    public uint preferred_threads() {
        return 1+get_num_processors()/2;
    }
}
