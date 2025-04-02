export class StringUtils {

	public static makeURLString(url: string, data?: object) {
		return data ? url + "?" + this.makeQueryParam(data) : url;
	}

	public static makeQueryParam(data: any) {
		if (!data) return "";

		let res = Object.keys(data).reduce(
			(res, key) => (res + key + '=' +
				this.convertParam(data[key]) + '&'), '');
		if (res !== '')
			res = res.substr(0, res.lastIndexOf('&'));

		return res;
	}

	public static convertParam(data: any) {
		let res = data;
		if (typeof data === 'object') res = JSON.stringify(res);
		return encodeURIComponent(res);
	}

	public line2Hump(str: string) {
		return str.replace(/\-(\w)/g,
			(all, letter) => letter.toUpperCase());
	}
	public hump2Line(str: string) {
		return str.replace(/([A-Z])/g,"-$1")
			.toLowerCase().substring(1);
	}

	public static fillData2Str(str: string, data: any, deleteKey = true) {
		const re = /:(.+?)(\/|$|&)/g;
		let res = str, match;

		while ((match = re.exec(str)) !== null) {
			res = res.replace(match[0], data[match[1]] + match[2])
			if (deleteKey) delete data[match[1]];
		}
		return res;
	}

}
