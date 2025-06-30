struct Buffer {
	float data[48000];
	int length = 48000;
	int offset = 0;

	Buffer() {}

	float & operator[](int index) { return data[(offset + index) % length]; }

	void move(int dx) {
		offset = (offset + dx) % length;
	}
	void read(float *data, int length) {
		for (int i = 0; i < length; ++i) data[i] = (*this)[i];
	}
	void write(const float *data, int length) {
		for (int i = 0; i < length; ++i) (*this)[i] = data[i];
	}
};
