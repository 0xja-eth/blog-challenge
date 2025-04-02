export class PromiseUtils {
	public static wait(time) {
		return new Promise<boolean>(resolve =>
			setTimeout(() => resolve(true), time)
		)
	}

	public static waitFor(cond, interval: number = 100, maxTimes: number = 10000,
												mode: 'timeout' | 'interval' = 'timeout', title?: string) {
		return new Promise<boolean>(resolve => {
			const check = async (success?, fail?) => {
				if (title) console.log("Waiting for:", title, cond);
				const res = await cond();
				if (title) console.log("Current result:", title, res);

				if (res || --maxTimes <= 0) {
					success && success(); resolve(res);
				} else fail && fail();
			}
			let check_;

			switch (mode) {
				case "timeout":
					check_ = () => check(null,
						() => setTimeout(check_, interval));
					check_().then();
					break;

				case "interval":
					check_ = () => check(() => clearInterval(handle));
					const handle = setInterval(check_, interval);
					break;
			}
		})
	}

	public static waitForResult<T>(promise: Promise<T>, maxWaitTime: number = 30000,
																 default_?: any, useReject: boolean = false) {
		return new Promise<T>((resolve, reject) => {
			setTimeout(() =>
				useReject ? reject(default_) : resolve(default_)
			, maxWaitTime);
			promise.then(resolve).catch(reject);
		})
	}

	private static retryColdDownTime: number = 3000;

	public static waitForRetry<T>(promise: () => Promise<T>, maxRetryTimes: number = 20,
								  								default_?: any, useReject: boolean = false) {
		return new Promise<T>((resolve, reject) => {
			let retryTimes = 0;
			let retry = () => {
				retryTimes++;
				if (retryTimes > maxRetryTimes)
					reject();
				else
					promise().then(res => resolve(res)).catch(rej => {setTimeout(retry, this.retryColdDownTime)});
			}
			retry();
		})
	}

	public static funcWrapper(main: Function, before: Function, after: Function) {
		before();
		try { return main() }
		finally { after(); }
	}
}
